// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakingRewards} from "../../src/StakingRewards.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title StakingRewardsLifecycleTest
 * @notice Lifecycle Stake → warp → Claim → Unstake y prorrateo entre 2 stakers (Fase 2).
 */
contract StakingRewardsLifecycleTest is Test {
    uint256 internal constant DURATION = 100;
    uint256 internal constant LOCKUP = 0;
    uint256 internal constant REWARD_POT = 1000 ether;
    uint256 internal constant STAKE_AMOUNT = 100 ether;

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
            IERC20(address(stakeToken)), IERC20(address(rewardToken)), owner, DURATION, LOCKUP
        );
    }

    function test_lifecycle_stake_warp_claim_unstake() public {
        stakeToken.mint(alice, STAKE_AMOUNT);
        rewardToken.mint(owner, REWARD_POT);

        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(staking), REWARD_POT));
        staking.notifyRewardAmount(REWARD_POT);
        vm.stopPrank();

        vm.startPrank(alice);
        stakeToken.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        assertEq(staking.totalSupply(), STAKE_AMOUNT);
        assertEq(staking.balanceOf(alice), STAKE_AMOUNT);

        vm.warp(block.timestamp + 50);

        assertEq(staking.earned(alice), 500 ether, "earned after 50s");

        uint256 rewardBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        staking.getReward();
        assertEq(rewardToken.balanceOf(alice) - rewardBefore, 500 ether, "claimed reward");
        assertEq(staking.earned(alice), 0, "earned cleared after claim");

        vm.prank(alice);
        staking.withdraw(STAKE_AMOUNT);
        assertEq(staking.balanceOf(alice), 0);
        assertEq(stakeToken.balanceOf(alice), STAKE_AMOUNT);
        assertEq(staking.totalSupply(), 0);
    }

    function test_lifecycle_twoStakers_proportionalSplit() public {
        uint256 pot = 150 ether;
        stakeToken.mint(alice, 100 ether);
        stakeToken.mint(bob, 50 ether);
        rewardToken.mint(owner, pot);

        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(staking), pot));
        staking.notifyRewardAmount(pot);
        vm.stopPrank();

        vm.startPrank(alice);
        stakeToken.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        stakeToken.approve(address(staking), 50 ether);
        staking.stake(50 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 100);

        assertEq(staking.earned(alice), 100 ether, "alice share");
        assertEq(staking.earned(bob), 50 ether, "bob share");
    }
}
