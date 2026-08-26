// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {StakingRewards} from "../src/StakingRewards.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title Deploy
 * @notice Demo local/testnet: mocks (opcional) + `StakingRewards` + mint + notify inicial.
 * @dev No usar mint automático como modelo de mainnet.
 *
 * Env (todas opcionales salvo que no uses mocks):
 * - `INITIAL_OWNER` (default: broadcaster)
 * - `REWARDS_DURATION` (default: 7 days)
 * - `LOCKUP_DURATION` (default: 0)
 * - `DEPLOY_MOCKS` — si `false`, exige `STAKE_TOKEN` y `REWARD_TOKEN`
 * - `SAME_TOKEN` — un solo mock para stake y reward (default false)
 * - `STAKE_NAME` / `STAKE_SYMBOL` / `REWARD_NAME` / `REWARD_SYMBOL`
 * - `MINT_AMOUNT` — mint a broadcaster (default 1_000_000 ether)
 * - `INITIAL_REWARD_POT` — transfer + notify (default 100_000 ether; 0 = skip notify)
 */
contract Deploy is Script {
    using SafeERC20 for IERC20;

    function run()
        external
        returns (StakingRewards staking, address stakeToken, address rewardToken)
    {
        address initialOwner = vm.envOr("INITIAL_OWNER", msg.sender);
        uint256 rewardsDuration = vm.envOr("REWARDS_DURATION", uint256(7 days));
        uint256 lockupDuration = vm.envOr("LOCKUP_DURATION", uint256(0));
        bool deployMocks = vm.envOr("DEPLOY_MOCKS", true);
        bool sameToken = vm.envOr("SAME_TOKEN", false);
        uint256 mintAmount = vm.envOr("MINT_AMOUNT", uint256(1_000_000 ether));
        uint256 initialPot = vm.envOr("INITIAL_REWARD_POT", uint256(100_000 ether));

        vm.startBroadcast();

        if (deployMocks) {
            if (sameToken) {
                MockERC20 dual = new MockERC20(
                    vm.envOr("STAKE_NAME", string("Stake Token")),
                    vm.envOr("STAKE_SYMBOL", string("STK"))
                );
                dual.mint(msg.sender, mintAmount);
                stakeToken = address(dual);
                rewardToken = address(dual);
            } else {
                MockERC20 stake = new MockERC20(
                    vm.envOr("STAKE_NAME", string("Stake Token")),
                    vm.envOr("STAKE_SYMBOL", string("STK"))
                );
                MockERC20 reward = new MockERC20(
                    vm.envOr("REWARD_NAME", string("Reward Token")),
                    vm.envOr("REWARD_SYMBOL", string("RWD"))
                );
                stake.mint(msg.sender, mintAmount);
                reward.mint(msg.sender, mintAmount);
                stakeToken = address(stake);
                rewardToken = address(reward);
            }
        } else {
            stakeToken = vm.envAddress("STAKE_TOKEN");
            rewardToken = vm.envAddress("REWARD_TOKEN");
        }

        staking = new StakingRewards(
            IERC20(stakeToken), IERC20(rewardToken), initialOwner, rewardsDuration, lockupDuration
        );

        if (initialPot > 0 && initialOwner == msg.sender) {
            IERC20(rewardToken).safeTransfer(address(staking), initialPot);
            staking.notifyRewardAmount(initialPot);
        }

        vm.stopBroadcast();

        console2.log("Stake token:", stakeToken);
        console2.log("Reward token:", rewardToken);
        console2.log("StakingRewards:", address(staking));
        console2.log("Owner:", initialOwner);
        console2.log("Rewards duration (s):", rewardsDuration);
        console2.log("Lockup duration (s):", lockupDuration);
        console2.log("Initial reward pot notified:", initialPot > 0 && initialOwner == msg.sender);
    }
}
