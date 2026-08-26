// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakingRewards} from "../src/StakingRewards.sol";
import {IStakingRewards} from "../src/interfaces/IStakingRewards.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title StakingRewardsPhase1Test
 * @notice Fase 1: wiring, views en estado cero y mutators aún `NotImplemented`.
 * @dev El lifecycle feliz completo vive en `StakingRewards.lifecycle.t.sol` (rojo hasta Fase 2).
 */
contract StakingRewardsPhase1Test is Test {
    uint256 internal constant REWARDS_DURATION = 7 days;
    uint256 internal constant LOCKUP_DURATION = 1 days;

    MockERC20 internal stakeToken;
    MockERC20 internal rewardToken;
    StakingRewards internal staking;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");

    function setUp() public {
        stakeToken = new MockERC20("Stake Token", "STK");
        rewardToken = new MockERC20("Reward Token", "RWD");
        staking = new StakingRewards(
            IERC20(address(stakeToken)),
            IERC20(address(rewardToken)),
            owner,
            REWARDS_DURATION,
            LOCKUP_DURATION
        );
    }

    function test_constructor_setsTokensAndDurations() public view {
        assertEq(address(staking.stakingToken()), address(stakeToken));
        assertEq(address(staking.rewardsToken()), address(rewardToken));
        assertEq(staking.owner(), owner);
        assertEq(staking.rewardsDuration(), REWARDS_DURATION);
        assertEq(staking.lockupDuration(), LOCKUP_DURATION);
        assertEq(staking.PRECISION(), 1e18);
        assertEq(staking.totalSupply(), 0);
        assertEq(staking.balanceOf(alice), 0);
        assertEq(staking.earned(alice), 0);
        assertEq(staking.rewardPerToken(), 0);
    }

    function test_constructor_revertsZeroAddress() public {
        vm.expectRevert(IStakingRewards.ZeroAddress.selector);
        new StakingRewards(IERC20(address(0)), IERC20(address(rewardToken)), owner, REWARDS_DURATION, 0);

        vm.expectRevert(IStakingRewards.ZeroAddress.selector);
        new StakingRewards(IERC20(address(stakeToken)), IERC20(address(0)), owner, REWARDS_DURATION, 0);

        // Ownable(v5) valida el owner en el constructor base antes del body.
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new StakingRewards(IERC20(address(stakeToken)), IERC20(address(rewardToken)), address(0), REWARDS_DURATION, 0);
    }

    function test_constructor_revertsZeroRewardsDuration() public {
        vm.expectRevert(IStakingRewards.ZeroAmount.selector);
        new StakingRewards(IERC20(address(stakeToken)), IERC20(address(rewardToken)), owner, 0, 0);
    }

    function test_constructor_allowsSameStakeAndRewardToken() public {
        StakingRewards same = new StakingRewards(
            IERC20(address(stakeToken)), IERC20(address(stakeToken)), owner, REWARDS_DURATION, 0
        );
        assertEq(address(same.stakingToken()), address(same.rewardsToken()));
    }

    function test_lastTimeRewardApplicable_zeroPeriodFinish() public {
        vm.warp(1000);
        assertEq(staking.lastTimeRewardApplicable(), 0);
    }

    function test_mutators_revertNotImplemented() public {
        bytes4 sel = StakingRewards.NotImplemented.selector;

        vm.expectRevert(sel);
        staking.stake(1);

        vm.expectRevert(sel);
        staking.withdraw(1);

        vm.expectRevert(sel);
        staking.getReward();

        vm.expectRevert(sel);
        staking.exit();

        vm.expectRevert(sel);
        staking.notifyRewardAmount(1);

        vm.expectRevert(sel);
        staking.setRewardsDuration(1);

        vm.expectRevert(sel);
        staking.setLockupDuration(1);
    }

    function test_formulas_idlePool_rewardPerTokenUnchanged() public view {
        // totalSupply == 0 → rewardPerToken == rewardPerTokenStored (0)
        assertEq(staking.rewardPerToken(), staking.rewardPerTokenStored());
        assertEq(staking.earned(alice), 0);
    }
}
