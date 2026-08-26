// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IStakingRewards} from "./interfaces/IStakingRewards.sol";

/**
 * @title StakingRewards
 * @notice Pool de staking con distribución de rewards O(1) estilo Synthetix.
 * @dev Accumulator `rewardPerTokenStored` + `updateReward`. CEI + SafeERC20 + ReentrancyGuard.
 *      `PRECISION = 1e18`. Sin loops sobre usuarios.
 *
 * Stake y reward pueden ser el mismo token; en ese caso el check de solvencia de `notify`
 * descuenta `totalSupply` del balance del vault.
 */
contract StakingRewards is IStakingRewards, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Escala interna del acumulador (fija en v1).
    uint256 public constant PRECISION = 1e18;

    IERC20 private immutable STAKING_TOKEN;
    IERC20 private immutable REWARDS_TOKEN;

    uint256 public rewardPerTokenStored;
    uint256 public rewardRate;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardsDuration;
    uint256 public lockupDuration;
    uint256 private _totalSupply;

    mapping(address account => uint256) private _balances;
    mapping(address account => uint256) public userRewardPerTokenPaid;
    mapping(address account => uint256) public rewards;
    mapping(address account => uint256) public unlockTime;

    /**
     * @notice Materializa el acumulador global y, si `account != 0`, la deuda del usuario.
     * @param account Usuario a actualizar, o `address(0)` solo para el acumulador global.
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
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

        STAKING_TOKEN = stakingToken_;
        REWARDS_TOKEN = rewardsToken_;
        rewardsDuration = rewardsDuration_;
        lockupDuration = lockupDuration_;
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
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @inheritdoc IStakingRewards
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored
            + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION) / _totalSupply;
    }

    /// @inheritdoc IStakingRewards
    function earned(address account) public view returns (uint256) {
        return _balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / PRECISION
            + rewards[account];
    }

    /// @inheritdoc IStakingRewards
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();

        _totalSupply += amount;
        _balances[msg.sender] += amount;
        unlockTime[msg.sender] = block.timestamp + lockupDuration;

        STAKING_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /// @inheritdoc IStakingRewards
    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (_balances[msg.sender] < amount) revert InsufficientStake();
        if (block.timestamp < unlockTime[msg.sender]) revert LockupActive();

        _totalSupply -= amount;
        _balances[msg.sender] -= amount;

        STAKING_TOKEN.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /// @inheritdoc IStakingRewards
    function getReward() external nonReentrant updateReward(msg.sender) {
        _payoutReward(msg.sender);
    }

    /// @inheritdoc IStakingRewards
    function exit() external nonReentrant updateReward(msg.sender) {
        uint256 bal = _balances[msg.sender];
        if (bal > 0) {
            if (block.timestamp < unlockTime[msg.sender]) revert LockupActive();
            _totalSupply -= bal;
            _balances[msg.sender] = 0;
            STAKING_TOKEN.safeTransfer(msg.sender, bal);
            emit Withdrawn(msg.sender, bal);
        }
        _payoutReward(msg.sender);
    }

    /// @inheritdoc IStakingRewards
    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        if (reward == 0) revert ZeroAmount();

        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        uint256 balance = REWARDS_TOKEN.balanceOf(address(this));
        if (address(STAKING_TOKEN) == address(REWARDS_TOKEN)) {
            // El balance incluye el stake; solo cuenta el excedente como rewards.
            if (balance < _totalSupply) revert RewardRateTooHigh();
            balance -= _totalSupply;
        }
        if (rewardRate > balance / rewardsDuration) revert RewardRateTooHigh();

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardAdded(reward);
    }

    /// @inheritdoc IStakingRewards
    function setRewardsDuration(uint256 duration) external onlyOwner {
        if (block.timestamp <= periodFinish) revert RewardPeriodActive();
        if (duration == 0) revert ZeroAmount();
        rewardsDuration = duration;
        emit RewardsDurationUpdated(duration);
    }

    /// @inheritdoc IStakingRewards
    function setLockupDuration(uint256 duration) external onlyOwner {
        lockupDuration = duration;
        emit LockupDurationUpdated(duration);
    }

    /**
     * @dev Effects → Interactions: pone `rewards[account]` a 0 y transfiere.
     * @param account Beneficiario (`msg.sender` en flujos públicos).
     */
    function _payoutReward(address account) private {
        uint256 reward = rewards[account];
        if (reward == 0) return;

        rewards[account] = 0;
        REWARDS_TOKEN.safeTransfer(account, reward);
        emit RewardPaid(account, reward);
    }
}
