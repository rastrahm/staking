// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakingRewards} from "../src/StakingRewards.sol";
import {IStakingRewards} from "../src/interfaces/IStakingRewards.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockERC20RevertOnTransfer} from "../src/mocks/MockERC20RevertOnTransfer.sol";

/**
 * @title StakingRewardsCoreTest
 * @notice Fase 2: constructor, errores de usuario y paths de stake/claim/withdraw.
 */
contract StakingRewardsCoreTest is Test {
    uint256 internal constant REWARDS_DURATION = 100;
    uint256 internal constant LOCKUP_DURATION = 0;

    MockERC20 internal stakeToken;
    MockERC20 internal rewardToken;
    StakingRewards internal staking;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

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

    function test_constructor_setsTokensAndDurations() public view {
        assertEq(address(staking.stakingToken()), address(stakeToken));
        assertEq(address(staking.rewardsToken()), address(rewardToken));
        assertEq(staking.owner(), owner);
        assertEq(staking.rewardsDuration(), REWARDS_DURATION);
        assertEq(staking.lockupDuration(), LOCKUP_DURATION);
        assertEq(staking.PRECISION(), 1e18);
    }

    function test_constructor_revertsZeroAddressAndZeroDuration() public {
        vm.expectRevert(IStakingRewards.ZeroAddress.selector);
        new StakingRewards(IERC20(address(0)), IERC20(address(rewardToken)), owner, REWARDS_DURATION, 0);

        vm.expectRevert(IStakingRewards.ZeroAddress.selector);
        new StakingRewards(IERC20(address(stakeToken)), IERC20(address(0)), owner, REWARDS_DURATION, 0);

        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new StakingRewards(IERC20(address(stakeToken)), IERC20(address(rewardToken)), address(0), REWARDS_DURATION, 0);

        vm.expectRevert(IStakingRewards.ZeroAmount.selector);
        new StakingRewards(IERC20(address(stakeToken)), IERC20(address(rewardToken)), owner, 0, 0);
    }

    function test_stake_revertsZeroAmount() public {
        _fundAndNotify(1000 ether);
        stakeToken.mint(alice, 1);
        vm.startPrank(alice);
        stakeToken.approve(address(staking), 1);
        vm.expectRevert(IStakingRewards.ZeroAmount.selector);
        staking.stake(0);
        vm.stopPrank();
    }

    function test_withdraw_revertsZeroAmountAndInsufficientStake() public {
        _fundAndNotify(1000 ether);
        _stakeAs(alice, 10 ether);

        vm.startPrank(alice);
        vm.expectRevert(IStakingRewards.ZeroAmount.selector);
        staking.withdraw(0);

        vm.expectRevert(IStakingRewards.InsufficientStake.selector);
        staking.withdraw(11 ether);
        vm.stopPrank();
    }

    function test_notify_revertsZeroAndNonOwnerAndRateTooHigh() public {
        vm.expectRevert(IStakingRewards.ZeroAmount.selector);
        vm.prank(owner);
        staking.notifyRewardAmount(0);

        vm.expectRevert();
        vm.prank(alice);
        staking.notifyRewardAmount(1 ether);

        // Sin tokens en el vault → rate no cabe en balance.
        vm.expectRevert(IStakingRewards.RewardRateTooHigh.selector);
        vm.prank(owner);
        staking.notifyRewardAmount(1000 ether);
    }

    function test_notify_setsRateAndPeriodFinish() public {
        uint256 pot = 1000 ether;
        _fundAndNotify(pot);

        assertEq(staking.rewardRate(), pot / REWARDS_DURATION);
        assertEq(staking.periodFinish(), block.timestamp + REWARDS_DURATION);
        assertEq(staking.lastUpdateTime(), block.timestamp);
    }

    function test_earned_accruesWithWarp_singleStaker() public {
        _fundAndNotify(1000 ether);
        _stakeAs(alice, 100 ether);

        vm.warp(block.timestamp + 50);
        assertEq(staking.earned(alice), 500 ether);
    }

    function test_getReward_transfersAndClearsEarned() public {
        _fundAndNotify(1000 ether);
        _stakeAs(alice, 100 ether);
        vm.warp(block.timestamp + 50);

        uint256 before_ = rewardToken.balanceOf(alice);
        vm.prank(alice);
        staking.getReward();

        assertEq(rewardToken.balanceOf(alice) - before_, 500 ether);
        assertEq(staking.earned(alice), 0);
        assertEq(staking.rewards(alice), 0);
    }

    function test_exit_withdrawsStakeAndPaysReward() public {
        _fundAndNotify(1000 ether);
        _stakeAs(alice, 100 ether);
        vm.warp(block.timestamp + 50);

        vm.prank(alice);
        staking.exit();

        assertEq(staking.balanceOf(alice), 0);
        assertEq(staking.totalSupply(), 0);
        assertEq(stakeToken.balanceOf(alice), 100 ether);
        assertEq(rewardToken.balanceOf(alice), 500 ether);
    }

    function test_setRewardsDuration_revertsWhilePeriodActive() public {
        _fundAndNotify(1000 ether);

        vm.expectRevert(IStakingRewards.RewardPeriodActive.selector);
        vm.prank(owner);
        staking.setRewardsDuration(200);
    }

    function test_setRewardsDuration_okAfterPeriod() public {
        _fundAndNotify(1000 ether);
        vm.warp(staking.periodFinish() + 1);

        vm.prank(owner);
        staking.setRewardsDuration(200);
        assertEq(staking.rewardsDuration(), 200);
    }

    function test_setLockupDuration_onlyOwner() public {
        vm.prank(owner);
        staking.setLockupDuration(1 days);
        assertEq(staking.lockupDuration(), 1 days);

        vm.expectRevert();
        vm.prank(alice);
        staking.setLockupDuration(0);
    }

    function test_sameToken_stakeAndReward_solvableNotify() public {
        MockERC20 token = new MockERC20("Dual", "DUAL");
        StakingRewards dual =
            new StakingRewards(IERC20(address(token)), IERC20(address(token)), owner, REWARDS_DURATION, 0);

        token.mint(alice, 100 ether);
        token.mint(owner, 1000 ether);

        vm.startPrank(owner);
        assertTrue(token.transfer(address(dual), 1000 ether));
        dual.notifyRewardAmount(1000 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        token.approve(address(dual), 100 ether);
        dual.stake(100 ether);
        vm.stopPrank();

        // Notify adicional: balance = 1100, totalStaked = 100 → disponible 1000.
        token.mint(owner, 100 ether);
        vm.startPrank(owner);
        assertTrue(token.transfer(address(dual), 100 ether));
        // leftover del periodo + 100; debe caber en (balance - totalSupply).
        dual.notifyRewardAmount(100 ether);
        vm.stopPrank();

        assertEq(dual.totalSupply(), 100 ether);
        assertGt(dual.rewardRate(), 0);
    }

    function test_stake_revertsWhenTransferFromFails() public {
        MockERC20RevertOnTransfer bad = new MockERC20RevertOnTransfer();
        StakingRewards pool =
            new StakingRewards(IERC20(address(bad)), IERC20(address(rewardToken)), owner, REWARDS_DURATION, 0);

        rewardToken.mint(owner, 1000 ether);
        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(pool), 1000 ether));
        pool.notifyRewardAmount(1000 ether);
        vm.stopPrank();

        bad.mint(alice, 10 ether);
        vm.startPrank(alice);
        // approve no usa transfer; stake sí → SafeERC20 revierte
        bad.approve(address(pool), 10 ether);
        vm.expectRevert(MockERC20RevertOnTransfer.AlwaysRevert.selector);
        pool.stake(10 ether);
        vm.stopPrank();
    }
}
