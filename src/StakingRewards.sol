// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IStakingRewards} from "./interfaces/IStakingRewards.sol";

/**
 * @title StakingRewards
 * @notice Esqueleto Fase 1 — superficie alineada a `IStakingRewards`; lógica en Fase 2+.
 * @dev Hereda Ownable2Step + ReentrancyGuard. Mutators revierten `NotImplemented` hasta Fase 2/3.
 *
 * PRECISION = 1e18 (ver NatSpec de la interfaz).
 */
contract StakingRewards is IStakingRewards, Ownable2Step, ReentrancyGuard {
    /// @notice Escala interna del acumulador (fija en v1).
    uint256 public constant PRECISION = 1e18;

    /// @dev Señal TDD: la función aún no tiene lógica de negocio.
    error NotImplemented();

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
    function stake(uint256) external pure {
        revert NotImplemented();
    }

    /// @inheritdoc IStakingRewards
    function withdraw(uint256) external pure {
        revert NotImplemented();
    }

    /// @inheritdoc IStakingRewards
    function getReward() external pure {
        revert NotImplemented();
    }

    /// @inheritdoc IStakingRewards
    function exit() external pure {
        revert NotImplemented();
    }

    /// @inheritdoc IStakingRewards
    function notifyRewardAmount(uint256) external pure {
        revert NotImplemented();
    }

    /// @inheritdoc IStakingRewards
    function setRewardsDuration(uint256) external pure {
        revert NotImplemented();
    }

    /// @inheritdoc IStakingRewards
    function setLockupDuration(uint256) external pure {
        revert NotImplemented();
    }
}
