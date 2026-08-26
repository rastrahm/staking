// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StakingRewards} from "../src/StakingRewards.sol";

/**
 * @title StakingRewardsBootstrapTest
 * @notice Smoke test Fase 0: el proyecto compila y el placeholder despliega.
 */
contract StakingRewardsBootstrapTest is Test {
    StakingRewards internal staking;

    function setUp() public {
        staking = new StakingRewards();
    }

    function test_moduleId() public view {
        assertEq(staking.moduleId(), "03-staking");
    }
}
