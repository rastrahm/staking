// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakingRewards} from "../../src/StakingRewards.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {StakingHandler} from "./StakingHandler.sol";

/**
 * @title StakingRewardsInvariantTest
 * @notice Solvencia: stake balance ≥ totalStaked; rewards balance ≥ Σ earned.
 */
contract StakingRewardsInvariantTest is StdInvariant, Test {
    StakingRewards internal staking;
    MockERC20 internal stakeToken;
    MockERC20 internal rewardToken;
    StakingHandler internal handler;

    address internal owner;

    function setUp() public {
        owner = makeAddr("owner");
        stakeToken = new MockERC20("STK", "STK");
        rewardToken = new MockERC20("RWD", "RWD");
        staking = new StakingRewards(
            IERC20(address(stakeToken)), IERC20(address(rewardToken)), owner, 7 days, 0
        );
        handler = new StakingHandler(staking, stakeToken, rewardToken, owner);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = StakingHandler.stake.selector;
        selectors[1] = StakingHandler.withdraw.selector;
        selectors[2] = StakingHandler.getReward.selector;
        selectors[3] = StakingHandler.warpTime.selector;
        selectors[4] = StakingHandler.notify.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice `stakingToken.balanceOf(vault) == totalSupply` bajo el handler (sin donaciones).
    function invariant_StakeTokenExact() public view {
        assertEq(stakeToken.balanceOf(address(staking)), staking.totalSupply());
        assertEq(staking.totalSupply(), handler.ghostTotalStaked());
        assertEq(handler.sumBalances(), staking.totalSupply());
    }

    /// @notice Solvencia de rewards: balance ≥ suma de earned de actores del handler.
    function invariant_RewardSolvency() public view {
        uint256 pending = handler.sumEarned();
        assertGe(rewardToken.balanceOf(address(staking)), pending);
    }
}
