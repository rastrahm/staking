// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakingRewards} from "../../src/StakingRewards.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title StakingHandler
 * @notice Handler para invariantes: stake / withdraw / claim / warp / notify.
 */
contract StakingHandler is Test {
    StakingRewards public immutable staking;
    MockERC20 public immutable stakeToken;
    MockERC20 public immutable rewardToken;
    address public immutable owner;

    address[] public actorsList;

    uint256 public ghostTotalStaked;

    constructor(
        StakingRewards staking_,
        MockERC20 stakeToken_,
        MockERC20 rewardToken_,
        address owner_
    ) {
        staking = staking_;
        stakeToken = stakeToken_;
        rewardToken = rewardToken_;
        owner = owner_;

        actorsList.push(makeAddr("actor0"));
        actorsList.push(makeAddr("actor1"));
        actorsList.push(makeAddr("actor2"));

        for (uint256 i = 0; i < actorsList.length; ++i) {
            stakeToken.mint(actorsList[i], 1_000_000 ether);
        }

        // Seed inicial de rewards en el vault.
        rewardToken.mint(owner, 10_000_000 ether);
        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(staking), 1_000_000 ether));
        staking.notifyRewardAmount(1_000_000 ether);
        vm.stopPrank();
    }

    function actors() external view returns (address[] memory) {
        return actorsList;
    }

    function stake(uint256 actorSeed, uint256 amount) external {
        address actor = actorsList[actorSeed % actorsList.length];
        uint256 wallet = stakeToken.balanceOf(actor);
        if (wallet == 0) return;
        amount = bound(amount, 1, wallet);

        vm.startPrank(actor);
        stakeToken.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();

        ghostTotalStaked += amount;
    }

    function withdraw(uint256 actorSeed, uint256 amount) external {
        address actor = actorsList[actorSeed % actorsList.length];
        uint256 bal = staking.balanceOf(actor);
        if (bal == 0) return;
        if (block.timestamp < staking.unlockTime(actor)) return;

        amount = bound(amount, 1, bal);

        vm.prank(actor);
        staking.withdraw(amount);

        ghostTotalStaked -= amount;
    }

    function getReward(uint256 actorSeed) external {
        address actor = actorsList[actorSeed % actorsList.length];
        if (staking.earned(actor) == 0) return;
        vm.prank(actor);
        staking.getReward();
    }

    function warpTime(uint256 secs) external {
        secs = bound(secs, 1, 7 days);
        vm.warp(block.timestamp + secs);
    }

    function notify(uint256 reward) external {
        // Solo re-fondear con periodo inactivo para no pelear con leftover vs balance.
        if (block.timestamp <= staking.periodFinish()) return;

        reward = bound(reward, 1 ether, 100_000 ether);
        rewardToken.mint(owner, reward);
        vm.startPrank(owner);
        assertTrue(rewardToken.transfer(address(staking), reward));
        staking.notifyRewardAmount(reward);
        vm.stopPrank();
    }

    function sumEarned() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actorsList.length; ++i) {
            sum += staking.earned(actorsList[i]);
        }
    }

    function sumBalances() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actorsList.length; ++i) {
            sum += staking.balanceOf(actorsList[i]);
        }
    }
}
