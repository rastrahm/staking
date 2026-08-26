// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakingRewards} from "../../src/StakingRewards.sol";
import {IStakingRewards} from "../../src/interfaces/IStakingRewards.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title StakingRewardsPhase3Test
 * @notice Bordes Fase 3: lockup con warp, notify mid-period, duration, earned intacto.
 */
contract StakingRewardsPhase3Test is Test {
    uint256 internal constant DURATION = 100;
    uint256 internal constant LOCKUP = 1 days;

    MockERC20 internal stakeToken;
    MockERC20 internal rewardToken;
    StakingRewards internal staking;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");

    function setUp() public {
        stakeToken = new MockERC20("Stake Token", "STK");
        rewardToken = new MockERC20("Reward Token", "RWD");
        staking = new StakingRewards(
            IERC20(address(stakeToken)), IERC20(address(rewardToken)), owner, DURATION, LOCKUP
        );
    }

    function _fundAndNotify(uint256 pot) internal {
        rewardToken.mint(owner, pot);
        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(staking), pot));
        staking.notifyRewardAmount(pot);
        vm.stopPrank();
    }

    function _stakeAs(address user, uint256 amount) internal {
        stakeToken.mint(user, amount);
        vm.startPrank(user);
        stakeToken.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Lockup
    // -------------------------------------------------------------------------

    function test_withdraw_revertsWhileLockupActive() public {
        _fundAndNotify(1000 ether);
        _stakeAs(alice, 10 ether);

        uint256 unlock = staking.unlockTime(alice);
        assertEq(unlock, block.timestamp + LOCKUP);

        vm.prank(alice);
        vm.expectRevert(IStakingRewards.LockupActive.selector);
        staking.withdraw(1 ether);

        vm.prank(alice);
        vm.expectRevert(IStakingRewards.LockupActive.selector);
        staking.exit();
    }

    function test_withdraw_okAtExactUnlockTime() public {
        _fundAndNotify(1000 ether);
        _stakeAs(alice, 10 ether);

        uint256 unlock = staking.unlockTime(alice);

        // Un segundo antes sigue bloqueado.
        vm.warp(unlock - 1);
        vm.prank(alice);
        vm.expectRevert(IStakingRewards.LockupActive.selector);
        staking.withdraw(10 ether);

        // Exactamente en unlockTime.
        vm.warp(unlock);
        vm.prank(alice);
        staking.withdraw(10 ether);

        assertEq(staking.balanceOf(alice), 0);
        assertEq(stakeToken.balanceOf(alice), 10 ether);
    }

    function test_getReward_allowedDuringLockup() public {
        _fundAndNotify(1000 ether);
        _stakeAs(alice, 100 ether);

        vm.warp(block.timestamp + 50);
        uint256 earned_ = staking.earned(alice);
        assertGt(earned_, 0);

        vm.prank(alice);
        staking.getReward();

        assertEq(rewardToken.balanceOf(alice), earned_);
        // Sigue en lockup: no puede unstake.
        vm.prank(alice);
        vm.expectRevert(IStakingRewards.LockupActive.selector);
        staking.withdraw(1);
    }

    function test_restake_extendsUnlockTime() public {
        _fundAndNotify(1000 ether);
        _stakeAs(alice, 5 ether);
        uint256 firstUnlock = staking.unlockTime(alice);

        vm.warp(block.timestamp + 1 hours);
        stakeToken.mint(alice, 5 ether);
        vm.startPrank(alice);
        stakeToken.approve(address(staking), 5 ether);
        staking.stake(5 ether);
        vm.stopPrank();

        uint256 secondUnlock = staking.unlockTime(alice);
        assertEq(secondUnlock, block.timestamp + LOCKUP);
        assertGt(secondUnlock, firstUnlock);
    }

    function test_setLockupDuration_onlyAffectsFutureStakes() public {
        _fundAndNotify(1000 ether);
        _stakeAs(alice, 5 ether);
        uint256 unlockBefore = staking.unlockTime(alice);

        vm.prank(owner);
        staking.setLockupDuration(7 days);

        assertEq(staking.unlockTime(alice), unlockBefore, "unlock existente no cambia");
        assertEq(staking.lockupDuration(), 7 days);
    }

    // -------------------------------------------------------------------------
    // setRewardsDuration
    // -------------------------------------------------------------------------

    function test_setRewardsDuration_revertsWhilePeriodActive_includingExactFinish() public {
        _fundAndNotify(1000 ether);
        uint256 finish = staking.periodFinish();

        vm.prank(owner);
        vm.expectRevert(IStakingRewards.RewardPeriodActive.selector);
        staking.setRewardsDuration(200);

        vm.warp(finish); // timestamp == periodFinish → aún activo por `<=`
        vm.prank(owner);
        vm.expectRevert(IStakingRewards.RewardPeriodActive.selector);
        staking.setRewardsDuration(200);

        vm.warp(finish + 1);
        vm.prank(owner);
        staking.setRewardsDuration(200);
        assertEq(staking.rewardsDuration(), 200);
    }

    function test_setRewardsDuration_revertsZero() public {
        _fundAndNotify(1000 ether);
        vm.warp(staking.periodFinish() + 1);

        vm.prank(owner);
        vm.expectRevert(IStakingRewards.ZeroAmount.selector);
        staking.setRewardsDuration(0);
    }

    // -------------------------------------------------------------------------
    // notify mid-period + earned intacto
    // -------------------------------------------------------------------------

    function test_notifyMidPeriod_preservesAlreadyEarned() public {
        _fundAndNotify(1000 ether); // rate = 10 ether / s
        _stakeAs(alice, 100 ether);

        vm.warp(block.timestamp + 40);
        uint256 earnedBefore = staking.earned(alice);
        assertEq(earnedBefore, 400 ether);

        // Fondea 400 más mid-period: leftover = 60 * 10 = 600 → rate = (400+600)/100 = 10
        rewardToken.mint(owner, 400 ether);
        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(staking), 400 ether));
        staking.notifyRewardAmount(400 ether);
        vm.stopPrank();

        assertEq(staking.earned(alice), earnedBefore, "earned no se resetea al re-fondear");
        assertEq(staking.rewardRate(), 10 ether);
        assertEq(staking.periodFinish(), block.timestamp + DURATION);
    }

    function test_notifyMidPeriod_leftoverMath() public {
        _fundAndNotify(1000 ether); // rate 10/s, duration 100
        _stakeAs(alice, 100 ether);

        vm.warp(block.timestamp + 25);
        // leftover = 75 * 10e18 = 750e18; add 250e18 → rate = 1000e18/100 = 10e18
        rewardToken.mint(owner, 250 ether);
        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(staking), 250 ether));
        staking.notifyRewardAmount(250 ether);
        vm.stopPrank();

        assertEq(staking.rewardRate(), 10 ether);

        vm.warp(block.timestamp + 100);
        // Ya había ~250 earned en los primeros 25s; luego 100s a rate 10 con sole staker = 1000
        // Total ≈ 250 + 1000 = 1250, acotado por tokens en vault (1250)
        assertEq(staking.earned(alice), 1250 ether);
    }

    function test_notify_afterPeriodEnds_freshRate() public {
        _fundAndNotify(1000 ether);
        _stakeAs(alice, 100 ether);
        vm.warp(staking.periodFinish() + 1);

        uint256 earnedEnd = staking.earned(alice);
        assertEq(earnedEnd, 1000 ether);

        rewardToken.mint(owner, 500 ether);
        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(staking), 500 ether));
        staking.notifyRewardAmount(500 ether);
        vm.stopPrank();

        assertEq(staking.rewardRate(), 5 ether); // 500/100
        assertEq(staking.earned(alice), earnedEnd, "earned previo intacto al nuevo periodo");
    }
}
