# Gas optimization — StakingRewards

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract 'StakingRewardsCoreTest|StakingRewardsLifecycleTest|StakingRewardsPhase3Test' --gas-report
```

---

## Applied changes (2026-08-26)

| Optimization | Tradeoff | Effect |
|--------------|----------|--------|
| `ReentrancyGuardTransient` (EIP-1153) | Cancun + OZ **v5.2.0** | Cheaper guard on every mutator |
| `uint64` ×4 packing (finish / lastUpdate / durations) | Capped at `type(uint64).max` | Fewer SLOAD/SSTORE in notify/stake |
| Cache `rewardPerToken` in `updateReward` + `_earned` | None | Avoids computing the accumulator twice |
| Cache `account = msg.sender` | None | Fewer `CALLER` |
| `unchecked` after subtraction checks | Checks must remain | Fewer overflow checks |
| OZ `v5.0.2` → `v5.2.0` | Pin aligned with module 02 | Enables transient |

---

## Yul in hot paths (2026-09-16)

| Optimization | Tradeoff | Effect |
|--------------|----------|--------|
| `lastTimeRewardApplicable` in assembly (`min(ts, finish)`) | Less readable | Fewer Solidity JUMPs/comparisons |
| `rewardPerToken`: 1× packed `SLOAD` + Yul `mul/div` | Mul overflow same as previous `unchecked` | Fewer SLOADs + more direct arithmetic |
| `_earned` in Yul (`mul/div/add`) | Guard `rpt < paid` → return pending | Less overhead on each materialization |

**Semantics:** same O(1) formula; suite **35/35** green (unit/fuzz/invariant/attack).

### Post-opt (packing/transient) → post-Yul

| Metric | Post-opt | Post-Yul | Δ |
|---------|----------|----------|---|
| Deployment Cost | 1 199 350 | 1 184 009 | **−15 341** |
| Deployment Size | 5872 | 5801 | **−71** bytes |
| `stake` avg | 120 432 | 120 157 | **−275** |
| `withdraw` avg | 64 112 | 63 704 | **−408** |
| `getReward` avg | 115 882 | 115 526 | **−356** |
| `exit` avg | 91 439 | 91 049 | **−390** |
| `notifyRewardAmount` avg | 60 050 | 60 033 | **−17** |
| `earned` avg | 15 325 | 14 947 | **−378** |

**Reading:** the savings are **marginal** (as anticipated), but consistent across views/mutators that touch the accumulator. Deploy also dropped slightly (more compact bytecode in the math).

### Post-Yul detail

| Function | Min | Avg | Median | Max |
|---------|-----|-----|--------|-----|
| `stake` | 35 690 | 120 157 | 129 389 | 129 401 |
| `withdraw` | 35 912 | 63 704 | 38 391 | 129 357 |
| `getReward` | 115 526 | 115 526 | 115 526 | 115 526 |
| `exit` | 38 084 | 91 049 | 91 049 | 144 014 |
| `notifyRewardAmount` | 23 819 | 60 033 | 63 203 | 66 330 |

---

## Before vs after (unit/lifecycle/phase3 suite) — packing/transient phase

| Metric | Before | After | Δ |
|---------|-------|---------|---|
| Deployment Cost | 1 166 857 | 1 199 350 | **+32 493** (OZ 5.2 + explicit getters) |
| Deployment Size | 5424 | 5872 | +448 bytes |
| `stake` avg | 127 790 | 120 432 | **−7 358** |
| `withdraw` avg | 73 311 | 64 112 | **−9 199** |
| `getReward` avg | 121 987 | 115 882 | **−6 105** |
| `exit` avg | 100 053 | 91 439 | **−8 614** |
| `notifyRewardAmount` avg | 92 169 | 60 050 | **−32 119** |

**Reading:** deploy goes up slightly (dependency + getter ABI); hot user/admin paths **drop** clearly, especially `notify` and `withdraw`.

---

## Accepted tradeoffs

| Decision | Why |
|----------|---------|
| Cancun + transient | Aligned with `02-crypto-bank` |
| `uint64` times/durations | Sufficient on-chain; overflow → revert |
| Slightly more expensive deploy (OZ 5.2 phase) | We prefer cheaper user runtime |
| SafeERC20 / Ownable2Step | Security > residual gas |
| Yul in math | Fine-grained savings; CEI/SafeERC20 intact; audit more carefully |

---

## Security

`test/attack/ReentrancyAttack.t.sol` green with transient: reentry → `ReentrancyGuardReentrantCall`, no draining. Full suite: **35 tests**.
