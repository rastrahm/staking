// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {IStakingRewards} from "./interfaces/IStakingRewards.sol";

/**
 * @title StakingRewards
 * @notice Pool de staking con distribución de rewards O(1) estilo Synthetix.
 * @dev Accumulator + CEI + SafeERC20 + `ReentrancyGuardTransient` (EIP-1153, Cancun).
 *      Gas: packing uint64 de tiempos/durations; cache `msg.sender`/`rewardPerToken`;
 *      `unchecked` en restas tras checks.
 *
 * Stake y reward pueden ser el mismo token; en ese caso el check de solvencia de `notify`
 * descuenta `totalSupply` del balance del vault.
 */
contract StakingRewards is IStakingRewards, Ownable2Step, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    /// @notice Escala interna del acumulador (fija en v1).
    uint256 public constant PRECISION = 1e18;

    IERC20 private immutable STAKING_TOKEN;
    IERC20 private immutable REWARDS_TOKEN;

    uint256 public rewardPerTokenStored;
    uint256 public rewardRate;
    uint256 private _totalSupply;

    // Un solo slot: timestamps + durations (uint64 basta hasta ~año 584e9).
    uint64 private _periodFinish;
    uint64 private _lastUpdateTime;
    uint64 private _rewardsDuration;
    uint64 private _lockupDuration;

    mapping(address account => uint256) private _balances;
    mapping(address account => uint256) public userRewardPerTokenPaid;
    mapping(address account => uint256) public rewards;
    mapping(address account => uint256) public unlockTime;

    /**
     * @notice Materializa el acumulador global y, si `account != 0`, la deuda del usuario.
     * @dev Cachea `rewardPerToken()` una sola vez (evita doble SLOAD/cálculo en `earned`).
     * @param account Usuario a actualizar, o `address(0)` solo para el acumulador global.
     */
    modifier updateReward(address account) {
        uint256 rpt = rewardPerToken();
        rewardPerTokenStored = rpt;
        _lastUpdateTime = uint64(lastTimeRewardApplicable());
        if (account != address(0)) {
            rewards[account] = _earned(account, rpt);
            userRewardPerTokenPaid[account] = rpt;
        }
        _;
    }

    /**
     * @notice Despliega el pool con tokens y owner inicial.
     * @param stakingToken_ Token de stake.
     * @param rewardsToken_ Token de reward (puede ser igual a `stakingToken_`).
     * @param owner_ Owner / distributor admin.
     * @param rewardsDuration_ Duración inicial del periodo (segundos).
     * @param lockupDuration_ Lockup inicial (segundos; 0 = sin lockup).
     */
    constructor(
        IERC20 stakingToken_,
        IERC20 rewardsToken_,
        address owner_,
        uint256 rewardsDuration_,
        uint256 lockupDuration_
    ) Ownable(owner_) {
        if (address(stakingToken_) == address(0) || address(rewardsToken_) == address(0) || owner_ == address(0)) {
            revert ZeroAddress();
        }
        if (rewardsDuration_ == 0) revert ZeroAmount();
        if (rewardsDuration_ > type(uint64).max || lockupDuration_ > type(uint64).max) revert ZeroAmount();

        STAKING_TOKEN = stakingToken_;
        REWARDS_TOKEN = rewardsToken_;
        _rewardsDuration = uint64(rewardsDuration_);
        _lockupDuration = uint64(lockupDuration_);
    }

    /// @inheritdoc IStakingRewards
    function stakingToken() external view returns (IERC20) {
        return STAKING_TOKEN;
    }

    /// @inheritdoc IStakingRewards
    function rewardsToken() external view returns (IERC20) {
        return REWARDS_TOKEN;
    }

    /// @inheritdoc IStakingRewards
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @inheritdoc IStakingRewards
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /// @inheritdoc IStakingRewards
    function periodFinish() external view returns (uint256) {
        return _periodFinish;
    }

    /// @inheritdoc IStakingRewards
    function rewardsDuration() external view returns (uint256) {
        return _rewardsDuration;
    }

    /// @inheritdoc IStakingRewards
    function lockupDuration() external view returns (uint256) {
        return _lockupDuration;
    }

    /// @notice Último timestamp en que se materializó el acumulador global.
    function lastUpdateTime() external view returns (uint256) {
        return _lastUpdateTime;
    }

    /// @inheritdoc IStakingRewards
    function lastTimeRewardApplicable() public view returns (uint256) {
        uint256 finish = _periodFinish;
        return block.timestamp < finish ? block.timestamp : finish;
    }

    /// @inheritdoc IStakingRewards
    function rewardPerToken() public view returns (uint256) {
        uint256 supply = _totalSupply;
        if (supply == 0) {
            return rewardPerTokenStored;
        }
        uint256 applicable = lastTimeRewardApplicable();
        uint256 last = _lastUpdateTime;
        if (applicable <= last) {
            return rewardPerTokenStored;
        }
        unchecked {
            return rewardPerTokenStored + ((applicable - last) * rewardRate * PRECISION) / supply;
        }
    }

    /// @inheritdoc IStakingRewards
    function earned(address account) public view returns (uint256) {
        return _earned(account, rewardPerToken());
    }

    /// @inheritdoc IStakingRewards
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();

        address account = msg.sender;
        _totalSupply += amount;
        _balances[account] += amount;
        // Política v1: cada stake reinicia unlock a now + lockupDuration.
        unlockTime[account] = block.timestamp + _lockupDuration;

        STAKING_TOKEN.safeTransferFrom(account, address(this), amount);

        emit Staked(account, amount);
    }

    /// @inheritdoc IStakingRewards
    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();

        address account = msg.sender;
        uint256 bal = _balances[account];
        if (bal < amount) revert InsufficientStake();
        if (block.timestamp < unlockTime[account]) revert LockupActive();

        unchecked {
            _totalSupply -= amount;
            _balances[account] = bal - amount;
        }

        STAKING_TOKEN.safeTransfer(account, amount);

        emit Withdrawn(account, amount);
    }

    /// @inheritdoc IStakingRewards
    function getReward() external nonReentrant updateReward(msg.sender) {
        _payoutReward(msg.sender);
    }

    /// @inheritdoc IStakingRewards
    function exit() external nonReentrant updateReward(msg.sender) {
        address account = msg.sender;
        uint256 bal = _balances[account];
        if (bal > 0) {
            if (block.timestamp < unlockTime[account]) revert LockupActive();
            unchecked {
                _totalSupply -= bal;
            }
            _balances[account] = 0;
            STAKING_TOKEN.safeTransfer(account, bal);
            emit Withdrawn(account, bal);
        }
        _payoutReward(account);
    }

    /// @inheritdoc IStakingRewards
    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        if (reward == 0) revert ZeroAmount();

        uint256 duration = _rewardsDuration;
        uint256 finish = _periodFinish;
        uint256 timestamp = block.timestamp;

        if (timestamp >= finish) {
            rewardRate = reward / duration;
        } else {
            unchecked {
                uint256 remaining = finish - timestamp;
                uint256 leftover = remaining * rewardRate;
                rewardRate = (reward + leftover) / duration;
            }
        }

        uint256 balance = REWARDS_TOKEN.balanceOf(address(this));
        if (address(STAKING_TOKEN) == address(REWARDS_TOKEN)) {
            uint256 staked = _totalSupply;
            if (balance < staked) revert RewardRateTooHigh();
            unchecked {
                balance -= staked;
            }
        }
        if (rewardRate > balance / duration) revert RewardRateTooHigh();

        _lastUpdateTime = uint64(timestamp);
        uint256 newFinish = timestamp + duration;
        if (newFinish > type(uint64).max) revert ZeroAmount();
        _periodFinish = uint64(newFinish);

        emit RewardAdded(reward);
    }

    /// @inheritdoc IStakingRewards
    function setRewardsDuration(uint256 duration) external onlyOwner {
        if (block.timestamp <= _periodFinish) revert RewardPeriodActive();
        if (duration == 0 || duration > type(uint64).max) revert ZeroAmount();
        _rewardsDuration = uint64(duration);
        emit RewardsDurationUpdated(duration);
    }

    /// @inheritdoc IStakingRewards
    function setLockupDuration(uint256 duration) external onlyOwner {
        if (duration > type(uint64).max) revert ZeroAmount();
        _lockupDuration = uint64(duration);
        emit LockupDurationUpdated(duration);
    }

    /**
     * @dev `earned` con `rewardPerToken` ya materializado (evita recálculo).
     */
    function _earned(address account, uint256 rpt) private view returns (uint256) {
        return _balances[account] * (rpt - userRewardPerTokenPaid[account]) / PRECISION + rewards[account];
    }

    /**
     * @dev Effects → Interactions: pone `rewards[account]` a 0 y transfiere.
     */
    function _payoutReward(address account) private {
        uint256 reward = rewards[account];
        if (reward == 0) return;

        rewards[account] = 0;
        REWARDS_TOKEN.safeTransfer(account, reward);
        emit RewardPaid(account, reward);
    }
}
