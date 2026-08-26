// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {StakingRewards} from "../src/StakingRewards.sol";

/**
 * @title Deploy
 * @notice Placeholder de deploy — se completará en Fase 5.
 */
contract Deploy is Script {
    function run() external returns (StakingRewards staking) {
        vm.startBroadcast();
        staking = new StakingRewards();
        vm.stopBroadcast();
    }
}
