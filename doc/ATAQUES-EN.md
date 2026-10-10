# Attack campaigns — StakingRewards

> **Protocol:** defensive Foundry tests (`vm.expectRevert` / invariants). The attack's “success” is that it **fails** or is documented as a limitation.  
> **Out of scope:** offensive exploit scripts or procedures to drain other users' funds.

Contract: `src/StakingRewards.sol`  
Audit: [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md)

---

## Summary

| Campaign | Name | SWC / topic | Status |
|---------|--------|------------|--------|
| A | Stake / withdraw / claim integrity | SWC-101, 123 | ✅ |
| B | Reentrancy (ERC-20 callback) | SWC-107 | ✅ |
| C | Tx ordering / external approve | SWC-114 | ✅ Documented |
| D | Time / lockup / notify | SWC-116 | ✅ |
| E | Solvency / fuzz / invariant | SWC-123, 128 | ✅ |

---

## Campaign A — Balance integrity

**Hypothesis:** nobody withdraws more stake than their own; zero amount reverts; a failed transfer does not leave half-applied state.

| # | Scenario | Expected result | Test |
|---|-----------|--------------------|------|
| A1 | `stake(0)` | `ZeroAmount` | `test_stake_revertsZeroAmount` |
| A2 | `withdraw` > balance | `InsufficientStake` | `test_withdraw_revertsZeroAmountAndInsufficientStake` |
| A3 | `withdraw(0)` | `ZeroAmount` | same |
| A4 | Stake `transferFrom` reverts | tx reverts; no credit | `test_stake_revertsWhenTransferFromFails` |
| A5 | Claim clears `earned` | reward transferred; earned 0 | `test_getReward_transfersAndClearsEarned` |
| A6 | `exit` withdraws stake + reward | balances 0 | `test_exit_withdrawsStakeAndPaysReward` |
| A7 | Non-owner `notify` | Ownable revert | `test_notify_revertsZeroAndNonOwnerAndRateTooHigh` |

---

## Campaign B — Reentrancy

**Hypothesis:** an ERC-20 with a callback in `transfer` cannot double-claim or double-withdraw.

| # | Scenario | Expected result | Test |
|---|-----------|--------------------|------|
| B1 | Reenter `getReward` during payout | `ReentrancyGuardReentrantCall`; vault intact | `test_getReward_reentrancyReverts_noDrain` |
| B2 | Reenter `withdraw` during unstake | same; stake intact | `test_withdraw_reentrancyReverts_noDrain` |

Mitigation: CEI (effects before transfer) + `nonReentrant`.

---

## Campaign C — Transaction ordering (SWC-114)

**Hypothesis:** the pool does not eliminate the stakingToken `approve` race.

| # | Scenario | Classification | Action |
|---|-----------|---------------|--------|
| C1 | `approve` N→M without going through 0 | ERC-20 limitation | Documented (see SWC-AUDIT) |

Off-chain mitigation: `approve(0)` then amount; or permit on the token.

---

## Campaign D — Time, lockup and funding

**Hypothesis:** lockup blocks unstake until `unlockTime`; a mid-period notify does not erase earned; duration does not change while a period is active.

| # | Scenario | Expected result | Test |
|---|-----------|--------------------|------|
| D1 | Withdraw before unlock | `LockupActive` | `test_withdraw_revertsWhileLockupActive` |
| D2 | Withdraw at exact `unlockTime` | OK | `test_withdraw_okAtExactUnlockTime` |
| D3 | `getReward` during lockup | OK | `test_getReward_allowedDuringLockup` |
| D4 | Mid-period notify | previous earned intact | `test_notifyMidPeriod_preservesAlreadyEarned` |
| D5 | `setRewardsDuration` with live period | `RewardPeriodActive` | phase3 + core |
| D6 | Restake extends unlock | new `unlockTime` | `test_restake_extendsUnlockTime` |

---

## Campaign E — Solvency under fuzz / invariant

**Hypothesis:** the vault does not promise more rewards than it holds; stake token matches `totalSupply`.

| # | Scenario | Expected result | Test |
|---|-----------|--------------------|------|
| E1 | Fuzz stake/withdraw | consistent balances | `testFuzz_stakeWithdraw_*` |
| E2 | Fuzz 2 stakers | bounded pro-rata | `testFuzz_twoStakers_proportional` |
| E3 | Underfunded notify | `RewardRateTooHigh` | `testFuzz_notify_revertsIfUnderfunded` |
| E4 | Stake invariant | `balance == totalSupply` | `invariant_StakeTokenExact` |
| E5 | Rewards invariant | `balance >= Σ earned` | `invariant_RewardSolvency` |

---

## Out of scope (v1)

- Fee-on-transfer / rebase tokens  
- Permit on the pool  
- Pausable / surplus rescue  
- Offensive exploits / real drain PoC  

See [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) informational section.
