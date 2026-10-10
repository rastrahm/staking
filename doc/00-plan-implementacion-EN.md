# Implementation Plan — Staking & Reward Distribution (Module 03)

Master document for the module. It defines the phases, deliverables, acceptance criteria and the **authorization protocol** used during development.

> **Current status:** Phases **0–7** ✅ (2026-08-27). See [`HANDOFF-EN.md`](./HANDOFF-EN.md).

---

## Authorization protocol

> **Hard rule:** each phase must be reviewed and **explicitly approved** by the project owner before the next one starts.  
> No implementation code for a phase is written without that confirmation.  
> When closing a phase: mark its status → `✅ Approved` + date; only then can the next one be requested.

| Status | Meaning |
|--------|-------------|
| 🔒 Pending authorization | Design ready; **do not execute** until OK |
| 🔄 In progress | Authorized and under development |
| ✅ Approved | Closed; the next one can be proposed |
| ⏸️ Paused | Blocked by an external decision |

**How to authorize:** reply in the chat with something like `Autorizo Fase N` ("I authorize Phase N") (or reject it with concrete changes).

---

## 1. Module goal

Build a **staking protocol with O(1) proportional reward distribution** that:

- Uses the **Synthetix**-style algorithm (`rewardPerTokenStored` + `userRewardPerTokenPaid` + `rewards`).
- Accrues rewards with `lastUpdateTime` and `rewardRate` **without loops** over users.
- Handles internal precision with fixed scaling **`PRECISION = 1e18`**.
- Supports **reward periods** and **dynamic lockups** (unstake subject to unlock).
- Handles ERC-20 stake and reward tokens safely (`SafeERC20`).
- Applies **CEI**, custom errors and NatSpec.
- Includes a Foundry suite: unit + `vm.warp` + fuzz + **solvency** invariant  
  (`rewardsToken.balance >= pendingClaimable`; stake `>= totalStaked`).
- Next.js + ethers v6 demo frontend (Phase 6 ✅).

---

## 2. Agreed stack

| Layer | Technology | Notes |
|------|------------|--------|
| Contracts | Solidity `0.8.24` (fixed pragma) | No floating pragma |
| Tooling | Foundry (`forge`, `cast`, `anvil`) | Unit, fuzz, invariant, gas |
| Libraries | OpenZeppelin **v5.2** | `SafeERC20`, `Ownable2Step`, `ReentrancyGuardTransient` (no Pausable in v1) |
| Math model | Synthetix-style accumulator | O(1); `PRECISION = 1e18` |
| Frontend | Next.js App Router + TS + ethers v6 + Zod | `frontend/src/` (Phase 6 ✅) |
| UI tests | Vitest + RTL | `frontend` — `npm test` |

**Out of scope for v1 (unless explicitly authorized):** multi-reward tokens, veToken/boost, liquid staking, bridges, The Graph, mainnet production hardening.

---

## 3. Logical architecture (summary)

```
User (MetaMask / cast)
        │
        ▼
[Optional] Next.js + ethers v6  ──RPC──►  Anvil / Testnet
        │                                      │
        └──────── ABI + address ───────────────┤
                                               ▼
                                    StakingRewards (core)
                          ┌────────────┼────────────────┐
                          ▼            ▼                ▼
                   balances[]    reward math      lockup / period
                   totalSupply   rewardPerToken   periodFinish / unlock
                          │            │
                          ▼            ▼
                   stakingToken   rewardsToken (IERC20)
```

Diagrams:

- [Class diagram](./01-diagrama-clases-EN.md)
- [Flow diagram](./02-diagrama-flujo-EN.md)
- [Flowchart](./03-flujograma-EN.md)

---

## 4. Repository structure (final)

```
03-staking/
├── .cursorrules
├── README.md
├── doc/                              # Plan, diagrams, HANDOFF, ABI
├── foundry.toml
├── remappings.txt
├── src/
│   ├── interfaces/IStakingRewards.sol
│   ├── StakingRewards.sol
│   └── mocks/MockERC20.sol
├── script/
│   ├── Deploy.s.sol
│   └── export-abi.sh
├── test/
│   ├── StakingRewards.t.sol          # core unit
│   ├── unit/StakingRewards.phase3.t.sol
│   ├── fuzz/StakingRewards.fuzz.t.sol
│   ├── invariant/StakingRewards.invariant.t.sol
│   └── attack/ReentrancyAttack.t.sol
└── frontend/
    ├── src/app/
    ├── src/components/
    ├── src/hooks/
    ├── src/lib/
    └── abi/
```

---

## 5. Planned on-chain surface (v1)

| Function / piece | Role |
|-----------------|-----|
| `stake(amount)` | Deposit staking token; `updateReward(msg.sender)` |
| `withdraw(amount)` | Withdraw stake (respecting lockup); `updateReward` |
| `getReward()` | Claim accrued rewards; `updateReward` |
| `exit()` | `withdraw` + `getReward` (optional) |
| `notifyRewardAmount(reward)` | Owner/distributor funds a period; adjusts `rewardRate` |
| `setRewardsDuration(duration)` | Only if no period is active (`RewardPeriodActive`) |
| `setLockupDuration(duration)` | Dynamic lockup for new stakes / agreed policy |
| Views | `earned`, `rewardPerToken`, `balanceOf`, `totalSupply`, `lastTimeRewardApplicable` |
| Modifier | `updateReward(account)` on user mutators |

### Custom errors (v1)

- `ZeroAmount()`
- `RewardPeriodActive()`
- `InsufficientStake()`
- `TransferFailed()` — reserved in the interface; the implementation uses SafeERC20/OZ
- `LockupActive()`
- `ZeroAddress()`
- `RewardRateTooHigh()`

### Vault invariant

```text
rewardsToken.balanceOf(vault) >= pendingClaimable
stakingToken.balanceOf(vault) >= totalStaked
# Same-token: balance covers stake + residual reward
# Donations → may be strictly >; do not require ==
```

---

## 6. Implementation phases

### Summary

| Phase | Name | Status |
|------|--------|--------|
| 0 | Foundry bootstrap + docs | ✅ Approved (2026-08-26) |
| 1 | On-chain design: interfaces, errors, math model + red tests | ✅ Approved (2026-08-26) |
| 2 | O(1) core implementation + unit tests (`vm.warp`) | ✅ Approved (2026-08-26) |
| 3 | Dynamic lockup + `notifyRewardAmount` / duration | ✅ Approved (2026-08-26) |
| 4 | Fuzz + invariants + attacks / gas report | ✅ Approved (2026-08-26) |
| 5 | Deploy scripts + ABI | ✅ Approved (2026-08-26) |
| 6 | Demo frontend (optional) | ✅ Approved (2026-08-27) |
| 7 | Final docs, handoff, diagram alignment | ✅ Approved (2026-08-27) |

---

### Phase 0 — Module bootstrap

**Status:** ✅ Approved — 2026-08-26  
**Estimated duration:** 0.5 day

#### Goal

Initialize Foundry, pin OZ v5, lock `0.8.24`, leave the layout ready.

#### Tasks

1. `forge init` (respecting the monorepo `.gitignore`).
2. `foundry.toml`: Solidity `0.8.24`, fuzz runs ≥ 1000, optimizer.
3. Install OpenZeppelin Contracts v5 + forge-std.
4. Remappings; `src/`, `test/`, `script/`, `doc/` structure.
5. Verify `forge build`.

#### Acceptance criteria

- [x] Compiles without errors.
- [x] Fixed pragma `0.8.24`.
- [x] OZ dependencies installed.
- [x] `doc/` present and referenced.

#### Result

- Foundry `1.4.3-stable` with `forge init --no-git --force`.
- `foundry.toml`: `solc = 0.8.24`, `evm_version = cancun`, fuzz `runs = 1000`, invariant configured.
- Dependencies: `forge-std` + `openzeppelin-contracts@v5.0.2` (submodules).
- Placeholder: `src/StakingRewards.sol`, `test/StakingRewards.t.sol`, `script/Deploy.s.sol`.
- Layout: `src/interfaces/`, `src/mocks/`, `test/{unit,fuzz,invariant}/`, `doc/`, `.env.example`, `README.md`.
- `forge build` OK; `forge test` → 1 passed (`test_moduleId`).
- Note: use `export PATH="$HOME/.foundry/bin:$PATH"` (the npm `forge` clashes with Foundry).

#### Approval

- [x] Authorized to execute  
- [x] Completed and reviewed → ✅ 2026-08-26

> Reply when you want to start **Phase 1**: `Autorizo Fase 1`

---

### Phase 1 — On-chain design + TDD (tests first)

**Status:** ✅ Approved — 2026-08-26  
**Estimated duration:** 1 day  
**Depends on:** Phase 0 ✅

#### Goal

Freeze the interface, errors, events and formulas; write failing tests / skeleton before the full logic.

#### Tasks

1. `IStakingRewards.sol` with full NatSpec.
2. Custom errors + events (`Staked`, `Withdrawn`, `RewardPaid`, `RewardAdded`, …).
3. Document formulas:
   - `rewardPerToken`
   - `earned(account)`
   - `lastTimeRewardApplicable`
4. Define the exact meaning of `unassignedRewards` / invariant.
5. `StakingRewards.sol` skeleton + initial unit suite (expected asserts).

#### Acceptance criteria

- [x] Compilable interfaces.
- [x] Custom errors only (no `require` strings).
- [x] Unit tests written for the Stake → warp → Claim → Unstake lifecycle (red until Phase 2).
- [x] Formulas written in NatSpec / `doc/04-modelo-matematico-EN.md`.

#### Result

- `src/interfaces/IStakingRewards.sol` — events, errors, views, mutators, NatSpec + formulas.
- `src/StakingRewards.sol` — Ownable2Step + ReentrancyGuardTransient skeleton; math views; mutators → `NotImplemented`.
- `src/mocks/MockERC20.sol` — mint for tests.
- `test/StakingRewards.t.sol` — 7 green tests (constructor, views, NotImplemented).
- `test/unit/StakingRewards.lifecycle.t.sol` — 2 **red** TDD tests (lifecycle + 2-staker pro-rata).
- `doc/04-modelo-matematico-EN.md` — PRECISION `1e18`, invariant, v1 decisions.
- Decisions: same token OK; no Pausable; `exit()` yes; no fee-on-transfer; notify with tokens already in the vault.

#### Approval

- [x] Authorized to execute  
- [x] Completed and reviewed → ✅ 2026-08-26

> Reply when you want to start **Phase 2**: `Autorizo Fase 2`

---

### Phase 2 — O(1) core implementation + unit tests

**Status:** ✅ Approved — 2026-08-26  
**Estimated duration:** 1–2 days  
**Depends on:** Phase 1 ✅

#### Goal

Implement the accumulator + `updateReward` + stake / withdraw / getReward with CEI and SafeERC20.

#### Tasks

1. State: `rewardPerTokenStored`, `userRewardPerTokenPaid`, `rewards`, `balances`, `totalSupply`, `rewardRate`, `periodFinish`, `lastUpdateTime`.
2. `updateReward(address account)` modifier.
3. `stake` / `withdraw` / `getReward` with CEI.
4. Scaling factor (`PRECISION = 1e18`) justified in NatSpec.
5. Unit tests with `vm.warp` / `vm.roll` for exact accrual.
6. Cases: zero amount, insufficient stake, transfer fail.

#### Acceptance criteria

- [x] Zero loops over user arrays.
- [x] Unit lifecycle green.
- [x] Rewards proportional to stake × time (cases with 1 and 2 stakers).
- [x] NatSpec on public/external functions.

#### Result

- Complete `StakingRewards.sol`: `updateReward`, stake/withdraw/getReward/exit, `notifyRewardAmount`, set durations.
- SafeERC20 + ReentrancyGuardTransient + CEI; `PRECISION = 1e18`.
- Same-token: notify solvency subtracts `totalSupply` from the balance.
- Basic lockup: `unlockTime = now + lockupDuration` on stake; `LockupActive` on withdraw/exit (details/edge cases in Phase 3).
- Suite: **16 green tests** (core + lifecycle).

#### Approval

- [x] Authorized to execute  
- [x] Completed and reviewed → ✅ 2026-08-26

> Reply when you want to start **Phase 3**: `Autorizo Fase 3`

---

### Phase 3 — Dynamic lockup + reward funding

**Status:** ✅ Approved — 2026-08-26  
**Estimated duration:** 1 day  
**Depends on:** Phase 2 ✅

#### Goal

Reward periods (`notifyRewardAmount`, `setRewardsDuration`) and dynamic lockups.

#### Tasks

1. `notifyRewardAmount` (authorized role only); leftover + new rate.
2. `setRewardsDuration` → revert `RewardPeriodActive` if a period is live.
3. Lockup policy: `unlockTime[user]` / configurable global duration.
4. `withdraw` respects the lockup → dedicated error if applicable.
5. Edge tests: mid-period notify, duration change outside a period, exact unlock with warp.

#### Acceptance criteria

- [x] Duration cannot be shortened/changed while a period is active.
- [x] Unstake blocked until unlock.
- [x] Funding does not break accounting of rewards already earned.

#### Result

- Documented policy: each stake resets `unlockTime = now + lockupDuration`; `setLockupDuration` does not touch existing unlocks.
- `getReward` allowed during lockup; `withdraw`/`exit` blocked until `unlockTime` (exact boundary inclusive OK).
- `setRewardsDuration`: reverts with `timestamp <= periodFinish`; OK at `finish + 1`.
- Mid-period notify: leftover + previously earned intact; new period after finish with a fresh rate.
- Suite: `test/unit/StakingRewards.phase3.t.sol` — **10 tests**; repo total **26 green**.

#### Approval

- [x] Authorized to execute  
- [x] Completed and reviewed → ✅ 2026-08-26

> Reply when you want to start **Phase 4**: `Autorizo Fase 4`

---

### Phase 4 — Fuzz, invariants, attacks, gas

**Status:** ✅ Approved — 2026-08-26  
**Estimated duration:** 1–2 days  
**Depends on:** Phase 3 ✅

#### Goal

Harden mathematical and security properties.

#### Tasks

1. Fuzz: amounts, durations, simulated multi-user.
2. Invariant: `totalStaked + unassignedRewards` vs vault balances.
3. Reentrancy attack on `getReward` / `withdraw` (must fail).
4. `forge test --gas-report` and tradeoff notes.
5. Branch coverage of explicit paths.

#### Acceptance criteria

- [x] Fuzz ≥ 1000 runs without breaking the invariant.
- [x] Reentrancy does not drain.
- [x] Baseline gas report documented (`doc/GAS-EN.md`).

#### Result

- `test/fuzz/StakingRewards.fuzz.t.sol` — 5 fuzz × 1000 runs.
- `test/invariant/` — handler + `StakeTokenExact` + `RewardSolvency` (256 runs / 3840 calls).
- `test/attack/ReentrancyAttack.t.sol` — ERC-20 callback on getReward/withdraw → `ReentrancyGuardReentrantCall`, no draining.
- `src/mocks/MockERC20Reentrant.sol`.
- `doc/GAS-EN.md` — deploy baseline ~1.15M gas; tradeoffs documented.
- Total suite: **35 green tests** (unit + fuzz + invariant + attack).

#### Approval

- [x] Authorized to execute  
- [x] Completed and reviewed → ✅ 2026-08-26

> Reply when you want to start **Phase 5**: `Autorizo Fase 5`

---

### Phase 5 — Deploy scripts + ABI

**Status:** ✅ Approved — 2026-08-26  
**Estimated duration:** 0.5 day  
**Depends on:** Phase 4 ✅

#### Goal

Reproducible deploy on Anvil/testnet and ABI export for the UI.

#### Tasks

1. `Deploy.s.sol` (staking token, rewards token, pool, optional initial notify).
2. `.env.example` without secrets.
3. Export ABI → `frontend/abi/` or `doc/abi/` depending on UI scope.
4. Anvil playbook in README/HANDOFF (once it exists).

#### Acceptance criteria

- [x] Deploy script green on Anvil.
- [x] Addresses + ABI documented.

#### Result

- `script/Deploy.s.sol` — optional mocks, `SAME_TOKEN`, mint, initial `notify`.
- `script/export-abi.sh` → `doc/abi/` + `frontend/abi/` (`StakingRewards`, `IStakingRewards`, `MockERC20`).
- `doc/DEPLOY-EN.md` — Anvil / testnet playbook.
- Verified on Anvil chain 31337: deploy + `notify` OK; `cast call rewardRate/periodFinish`.

#### Approval

- [x] Authorized to execute  
- [x] Completed and reviewed → ✅ 2026-08-26

> Reply: **`Autorizo Fase 6`** (frontend) or **`Omitir Fase 6`** ("Skip Phase 6") to go to Phase 7.

---

### Phase 6 — Demo frontend (optional)

**Status:** ✅ Completed (2026-08-27)  
**Estimated duration:** 2–3 days  
**Depends on:** Phase 5 ✅

#### Goal

Next.js demo: connect wallet, stake, claim, unstake, view `earned`.

#### Tasks

1. App Router; explicit `'use client'` / `'use server'`.
2. ethers v6 + Zod + JSDoc.
3. Flows: approve + stake, getReward, withdraw (lockup UX).
4. Vitest + RTL (interaction TDD).
5. `.env.example` with `NEXT_PUBLIC_*`.

#### Acceptance criteria

- [x] Happy path documented (`doc/FRONTEND-EN.md`).
- [x] `next build` OK.
- [x] Minimal UI tests green.

#### Approval

- [x] Authorized to execute (or **skipped** by decision)  
- [x] Completed / skipped → ✅ 2026-08-27

> **Do not start Phase 6 without:** `Autorizo Fase 6` (or `Omitir Fase 6`)

---

### Phase 7 — Final docs and handoff

**Status:** ✅ Completed (2026-08-27)  
**Estimated duration:** 0.5–1 day  
**Depends on:** Phase 5 ✅ (and Phase 6 if it was not skipped)

#### Goal

Align diagrams with the final code; README usable by a third party.

#### Tasks

1. Module README.
2. Update diagrams if there were deviations.
3. HANDOFF / limitations / improvements (if those files are authorized).
4. Global Definition of Done checklist.

#### Acceptance criteria

- [x] `doc/` consistent with the implementation.
- [x] A third party can test/deploy by following the docs.

#### Approval

- [x] Authorized to execute  
- [x] Completed and reviewed → ✅ 2026-08-27

> **Do not start Phase 7 without:** `Autorizo Fase 7`

---

## 7. Progress checklist

```text
[x] Phase 0  Foundry bootstrap         → ✅ 2026-08-26
[x] Phase 1  Design + TDD              → ✅ 2026-08-26
[x] Phase 2  Core O(1) + unit          → ✅ 2026-08-26
[x] Phase 3  Lockup + notify           → ✅ 2026-08-26
[x] Phase 4  Fuzz / invariant / gas    → ✅ 2026-08-26
[x] Phase 5  Deploy + ABI              → ✅ 2026-08-26
[x] Phase 6  Frontend (optional)       → ✅ 2026-08-27
[x] Phase 7  Final docs                → ✅ 2026-08-27
```

---

## 8. Definition of Done (global)

1. [x] Fixed `pragma solidity 0.8.24`.
2. [x] O(1) rewards; no iteration over users.
3. [x] `updateReward` on `stake` / `withdraw` / `getReward` (and `exit` / `notify`).
4. [x] Scaling factor documented (`PRECISION = 1e18`); precision verified in tests with warp.
5. [x] CEI + SafeERC20; custom errors.
6. [x] Dynamic lockup and reward periods with `RewardPeriodActive` where applicable.
7. [x] Suite: unit + fuzz + invariant (+ reentrancy attack).
8. [x] Vault invariant upheld.
9. [x] Diagrams and plan updated at close (`HANDOFF-EN.md`, class diagram aligned to Transient).
10. [x] Frontend authorized and implemented (Phase 6).

---

## 9. Risks and mitigations

| Risk | Mitigation |
|--------|------------|
| Precision / dust in division | `1e18` scaling; fuzz + bounding asserts |
| Miscalibrated `notifyRewardAmount` | Mid-period tests; explicit leftover |
| Lockup griefing UX | Events + `unlockTime` views; clear docs |
| Reentrancy on claim/withdraw | CEI + ReentrancyGuardTransient + malicious test |
| Fee-on-transfer token | Out of scope for v1 |
| Progress without review | **Per-phase authorization protocol** |

---

## 10. Immediate next step

**Current status:** Phases **0–7** closed. Module ready for handoff.

Recommended entry point for a third party: [`HANDOFF-EN.md`](./HANDOFF-EN.md).
