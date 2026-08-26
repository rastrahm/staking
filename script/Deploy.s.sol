// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakingRewards} from "../src/StakingRewards.sol";

/**
 * @title Deploy
 * @notice Placeholder de deploy — se completará en Fase 5 (tokens + notify).
 * @dev Requiere env: STAKE_TOKEN, REWARD_TOKEN, OWNER, REWARDS_DURATION, LOCKUP_DURATION.
 */
contract Deploy is Script {
    function run() external returns (StakingRewards staking) {
        address stakeToken = vm.envAddress("STAKE_TOKEN");
        address rewardToken = vm.envAddress("REWARD_TOKEN");
        address owner_ = vm.envOr("OWNER", msg.sender);
        uint256 rewardsDuration = vm.envOr("REWARDS_DURATION", uint256(7 days));
        uint256 lockupDuration = vm.envOr("LOCKUP_DURATION", uint256(0));

        vm.startBroadcast();
        staking = new StakingRewards(
            IERC20(stakeToken), IERC20(rewardToken), owner_, rewardsDuration, lockupDuration
        );
        vm.stopBroadcast();
    }
}
