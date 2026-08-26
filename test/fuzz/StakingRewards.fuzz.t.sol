// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakingRewards} from "../../src/StakingRewards.sol";
import {IStakingRewards} from "../../src/interfaces/IStakingRewards.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title StakingRewardsFuzzTest
 * @notice Fuzz de montos, tiempos y prorrateo entre 2 stakers.
 */
contract StakingRewardsFuzzTest is Test {
    uint256 internal constant DURATION = 7 days;

    MockERC20 internal stakeToken;
    MockERC20 internal rewardToken;
    StakingRewards internal staking;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        stakeToken = new MockERC20("STK", "STK");
        rewardToken = new MockERC20("RWD", "RWD");
        staking = new StakingRewards(
            IERC20(address(stakeToken)), IERC20(address(rewardToken)), owner, DURATION, 0
        );
    }

    function _notify(uint256 pot) internal {
        rewardToken.mint(owner, pot);
        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(staking), pot));
        staking.notifyRewardAmount(pot);
        vm.stopPrank();
    }

    function testFuzz_stakeWithdraw_restoresBalances(uint256 stakeAmount, uint256 withdrawAmount) public {
        stakeAmount = bound(stakeAmount, 1, 1_000_000 ether);
        withdrawAmount = bound(withdrawAmount, 1, stakeAmount);

        _notify(DURATION * 1 ether); // rate >= 1 wei/s solvency

        stakeToken.mint(alice, stakeAmount);
        vm.startPrank(alice);
        stakeToken.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        staking.withdraw(withdrawAmount);
        vm.stopPrank();

        assertEq(staking.balanceOf(alice), stakeAmount - withdrawAmount);
        assertEq(staking.totalSupply(), stakeAmount - withdrawAmount);
        assertEq(stakeToken.balanceOf(address(staking)), stakeAmount - withdrawAmount);
        assertEq(stakeToken.balanceOf(alice), withdrawAmount);
    }

    function testFuzz_earned_scalesWithTime(uint256 stakeAmount, uint256 elapsed) public {
        stakeAmount = bound(stakeAmount, 1 ether, 100_000 ether);
        elapsed = bound(elapsed, 1, DURATION);

        uint256 pot = DURATION * 10 ether;
        _notify(pot);

        stakeToken.mint(alice, stakeAmount);
        vm.startPrank(alice);
        stakeToken.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        uint256 t0 = block.timestamp;
        vm.warp(t0 + elapsed);

        uint256 expected = elapsed * staking.rewardRate(); // sole staker (ideal)
        // Truncamiento del acumulador (división entera).
        assertApproxEqAbs(staking.earned(alice), expected, 1e5);
    }

    function testFuzz_twoStakers_proportional(uint256 stakeA, uint256 stakeB, uint256 elapsed) public {
        stakeA = bound(stakeA, 1 ether, 50_000 ether);
        stakeB = bound(stakeB, 1 ether, 50_000 ether);
        elapsed = bound(elapsed, 1, DURATION);

        uint256 pot = DURATION * 10 ether;
        _notify(pot);

        stakeToken.mint(alice, stakeA);
        stakeToken.mint(bob, stakeB);

        vm.startPrank(alice);
        stakeToken.approve(address(staking), stakeA);
        staking.stake(stakeA);
        vm.stopPrank();

        vm.startPrank(bob);
        stakeToken.approve(address(staking), stakeB);
        staking.stake(stakeB);
        vm.stopPrank();

        vm.warp(block.timestamp + elapsed);

        uint256 earnedA = staking.earned(alice);
        uint256 earnedB = staking.earned(bob);
        uint256 total = earnedA + earnedB;

        // Prorrateo: earnedA / stakeA ≈ earnedB / stakeB  ⇒  earnedA * stakeB ≈ earnedB * stakeA
        // Tolerancia por truncamiento del acumulador.
        assertApproxEqAbs(earnedA * stakeB, earnedB * stakeA, stakeA + stakeB + elapsed);

        // Solvencia: no se promete más de lo emitido en el intervalo (sole pool rate * time).
        uint256 emitted = elapsed * staking.rewardRate();
        assertLe(total, emitted);
        assertGe(rewardToken.balanceOf(address(staking)), total);
    }

    function testFuzz_stake_revertsZero(uint256 noise) public {
        noise = bound(noise, 0, 1); // fuerza path
        _notify(DURATION * 1 ether);
        vm.expectRevert(IStakingRewards.ZeroAmount.selector);
        vm.prank(alice);
        staking.stake(0);
    }

    function testFuzz_notify_revertsIfUnderfunded(uint256 reward) public {
        reward = bound(reward, DURATION, 1_000_000 ether); // rate = reward/DURATION >= 1
        // Sin transferir tokens al vault.
        vm.prank(owner);
        vm.expectRevert(IStakingRewards.RewardRateTooHigh.selector);
        staking.notifyRewardAmount(reward);
    }
}
