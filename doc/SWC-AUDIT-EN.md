# SWC Audit — StakingRewards

Verification of `StakingRewards` against the [SWC Registry](https://swcregistry.io/) (EIP-1470) and monorepo principles (CEI, `ReentrancyGuardTransient`, O(1), custom errors, SafeERC20).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement with [SCSVS](https://github.com/ComposableSecurity/SCSVS) and [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Audited contract:** `src/StakingRewards.sol` (+ `src/interfaces/IStakingRewards.sol`)  
**Date:** 2026-08-26  
**Test reference:** `test/StakingRewards.t.sol`, `test/unit/`, `test/fuzz/`, `test/invariant/`, `test/attack/`  
**Model:** [`04-modelo-matematico-EN.md`](./04-modelo-matematico-EN.md)

---

## Executive summary

| Status | Count |
|--------|----------|
| ✅ Mitigated / Not applicable | 33 |
| ⚠️ Informational (design / standard / trust) | 3 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities within the scope of the Synthetix-style pool. Informational risks: reliance on `block.timestamp`, the external ERC-20 `approve` race, and trust in the owner + honest tokens (no fee-on-transfer / rebase).

**Verified suite principles:**

| Principle | Status |
|-----------|--------|
| CEI before transfers | ✅ `stake` / `withdraw` / `getReward` / `exit` |
| `ReentrancyGuardTransient` (EIP-1153) | ✅ + ERC-20 callback tests |
| No loops over users | ✅ O(1) accumulator |
| SafeERC20 | ✅ |
| Custom errors (no `require` strings) | ✅ |
| Fixed pragma `0.8.24` | ✅ |
| Ownable2Step | ✅ admin `notify` / durations |

---

## Full SWC-100 — SWC-136 matrix

| ID | Title | Applies | Status | Evidence in `StakingRewards` |
|----|--------|--------|--------|-------------------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility on all functions |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; checks `amount > 0`, `balance >= amount` |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | `SafeERC20.safeTransfer` / `safeTransferFrom` |
| SWC-105 | Unprotected Ether Withdrawal | No | N/A | No ETH / `payable` / `.call{value}` |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Yes | ✅ | CEI + `ReentrancyGuardTransient`; `test/attack/ReentrancyAttack.t.sol` |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Tokens/`_balances`/`_totalSupply` private; explicit getters |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` |
| SWC-113 | DoS with Failed Call | Partial | ✅ | Transfer failure → entire tx reverts (state intact) |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | `approve` race on the stake ERC-20 (external) |
| SWC-115 | Authorization through tx.origin | No | N/A | `tx.origin` not used; OZ `onlyOwner` |
| SWC-116 | Block values as a proxy for time | Yes | ⚠️ | `block.timestamp` for rate/lockup (accepted Synthetix usage) |
| SWC-117 | Signature Malleability | No | N/A | No signatures / `ecrecover` / permit |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No shadowing with OZ `Ownable2Step` / `ReentrancyGuardTransient` |
| SWC-120 | Weak Sources of Randomness | No | N/A | No RNG |
| SWC-121 | Missing Protection against Signature Replay | No | N/A | No signatures |
| SWC-122 | Lack of Proper Signature Verification | No | N/A | No signature verification |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + unit/fuzz/invariant |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | No storage assembly |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `IStakingRewards, Ownable2Step, ReentrancyGuardTransient` |
| SWC-126 | Insufficient Gas Griefing | No | N/A | No relayers with fixed stipend |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Yes | ✅ | O(1) paths; no loops over stakers |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge build` / tests |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead code (`TransferFailed` reserved in interface) |
| SWC-132 | Unexpected Ether balance | No | N/A | Contract does not handle ETH |
| SWC-133 | Hash Collisions (var-length args) | No | N/A | No custom multi-dynamic hashing |
| SWC-134 | Message call with hardcoded gas | No | N/A | No `{gas: …}` |
| SWC-135 | Code With No Effects | No | N/A | No relevant no-ops |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Balances/earned public by DeFi design |

---

## Informational risks

### SWC-114 — `approve` front-running (stake ERC-20)

The pool does not manage allowances. The user must `approve(staking, amount)` on the **stakingToken** before `stake`. That `approve` inherits the classic ERC-20 race.

**Product mitigation:** `approve(0)` → new amount, or a token with `permit` / `increaseAllowance`.

### SWC-116 — `block.timestamp` as clock

`lastTimeRewardApplicable`, `periodFinish`, `unlockTime` and `notifyRewardAmount` depend on `block.timestamp`. Miners/validators can skew seconds, not economically rewrite long periods.

**Status:** ⚠️ By design (Synthetix and nearly all on-chain staking). Accepted in v1.

### Owner trust + non-standard tokens

| Topic | Risk | v1 treatment |
|------|--------|----------------|
| `notifyRewardAmount` / durations | A malicious owner can manipulate rate/duration (cannot steal others' stake via someone else's withdraw) | Trust in owner; Ownable2Step |
| High `setLockupDuration` | Griefing of **new** stakes (resets unlock); existing unlocks intact | Documented; claim still OK during lockup |
| Fee-on-transfer / rebase | Incorrect accounting | **Out of scope** — honest ERC-20s only |
| Same token stake==reward | Notify solvency subtracts `totalSupply` | Covered + test |
| Empty pool (`totalSupply == 0`) | Emission does not advance the accumulator (rewards stay in vault / dust) | Classic Synthetix behavior |
| No `rescue` / Pausable | Excess donated tokens may get stuck; no global pause | Accepted v1 (smaller surface) |

---

## Monorepo principles checklist (09-security / suite)

| Principle | Compliant? | Notes |
|-----------|----------|--------|
| Checks-Effects-Interactions | ✅ | Balance/reward effects before `safeTransfer*` |
| Pull over Push | ✅ | User calls `getReward` / `withdraw` (no automatic push) |
| ReentrancyGuardTransient | ✅ | + CEI; callback attack documented |
| Admin access control | ✅ | `onlyOwner` on notify/set* |
| Custom errors | ✅ | `ZeroAmount`, `InsufficientStake`, `LockupActive`, … |
| O(1) gas / no user loops | ✅ | Accumulator `rewardPerTokenStored` |
| SafeERC20 | ✅ | |
| Solvency invariants | ✅ | `invariant_StakeTokenExact`, `invariant_RewardSolvency` |

---

## SWC → tests mapping

| SWC | Test(s) |
|-----|---------|
| SWC-101 | fuzz stake/withdraw; unit insufficient / zero |
| SWC-104 / 113 | `test_stake_revertsWhenTransferFromFails` |
| SWC-107 | `test_getReward_reentrancyReverts_noDrain`, `test_withdraw_reentrancyReverts_noDrain` |
| SWC-114 | Documented (external approve); no permit surface in pool |
| SWC-116 | phase3 lockup/`vm.warp`; mid-period notify |
| SWC-123 | unit + fuzz + invariant |
| SWC-128 | O(1) design; multi-actor invariant without on-chain loops |

---

## References

- [SWC Registry](https://swcregistry.io/)
- Campaigns: [`ATAQUES-EN.md`](./ATAQUES-EN.md)
- Model: [`04-modelo-matematico-EN.md`](./04-modelo-matematico-EN.md)
- Gas: [`GAS-EN.md`](./GAS-EN.md)
