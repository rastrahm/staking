// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {StakingRewards} from "../../src/StakingRewards.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockERC20Reentrant} from "../../src/mocks/MockERC20Reentrant.sol";

/**
 * @title ReentrancyAttackTest
 * @notice Reentrada vía callback ERC-20; `nonReentrant` hace revertir toda la tx (no drena).
 */
contract ReentrancyAttackTest is Test {
    uint256 internal constant DURATION = 100;

    address internal owner = makeAddr("owner");
    address internal attackerEOA = makeAddr("attackerEOA");

    function test_getReward_reentrancyReverts_noDrain() public {
        MockERC20 stakeToken = new MockERC20("STK", "STK");
        MockERC20Reentrant rewardToken = new MockERC20Reentrant("RWD", "RWD");

        StakingRewards staking = new StakingRewards(
            IERC20(address(stakeToken)), IERC20(address(rewardToken)), owner, DURATION, 0
        );

        rewardToken.mint(owner, 1000 ether);
        vm.startPrank(owner);
        assertTrue(IERC20(address(rewardToken)).transfer(address(staking), 1000 ether));
        staking.notifyRewardAmount(1000 ether);
        vm.stopPrank();

        stakeToken.mint(attackerEOA, 100 ether);
        vm.startPrank(attackerEOA);
        stakeToken.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 50);
        assertEq(staking.earned(attackerEOA), 500 ether);

        rewardToken.setReenter(address(staking), abi.encodeWithSelector(staking.getReward.selector));

        uint256 vaultRewardsBefore = rewardToken.balanceOf(address(staking));

        vm.prank(attackerEOA);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        staking.getReward();

        // Estado intacto: no pagó, vault no drenado.
        assertEq(rewardToken.balanceOf(attackerEOA), 0);
        assertEq(rewardToken.balanceOf(address(staking)), vaultRewardsBefore);
        assertEq(staking.earned(attackerEOA), 500 ether);
    }

    function test_withdraw_reentrancyReverts_noDrain() public {
        MockERC20Reentrant stakeToken = new MockERC20Reentrant("STK", "STK");
        MockERC20 rewardToken = new MockERC20("RWD", "RWD");

        StakingRewards staking = new StakingRewards(
            IERC20(address(stakeToken)), IERC20(address(rewardToken)), owner, DURATION, 0
        );

        rewardToken.mint(owner, 1000 ether);
        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(staking), 1000 ether));
        staking.notifyRewardAmount(1000 ether);
        vm.stopPrank();

        stakeToken.mint(attackerEOA, 100 ether);
        vm.startPrank(attackerEOA);
        stakeToken.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();

        stakeToken.setReenter(
            address(staking), abi.encodeWithSelector(staking.withdraw.selector, uint256(100 ether))
        );

        vm.prank(attackerEOA);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        staking.withdraw(100 ether);

        assertEq(staking.balanceOf(attackerEOA), 100 ether);
        assertEq(stakeToken.balanceOf(address(staking)), 100 ether);
        assertEq(stakeToken.balanceOf(attackerEOA), 0);
    }
}
