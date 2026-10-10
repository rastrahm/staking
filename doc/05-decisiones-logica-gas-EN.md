# Comprehension guide — StakingRewards (v1)

Document to **understand** the module: technical decisions, protocol logic, and the real room for gas improvement.  
Complements [`04-modelo-matematico-EN.md`](./04-modelo-matematico-EN.md), [`GAS-EN.md`](./GAS-EN.md) and [`HANDOFF-EN.md`](./HANDOFF-EN.md).

---

## 1. What problem it solves

We want to distribute a **pot of rewards** among those holding staked tokens, proportionally to their stake and time, **without** iterating over the user list on every block (that would be O(n) and infeasible).

The classic solution (Synthetix) is a **global accumulator** (`rewardPerTokenStored`) + a per-user “debt” (`userRewardPerTokenPaid` / `rewards`). Every time someone stakes, withdraws, or claims, the accrual so far is **materialized** and their snapshot is updated.

---

## 2. Technical decisions (v1)

### 2.1 Stack and security

| Decision | Why |
|----------|---------|
| Pinned Solidity **`0.8.24`** | No floating pragma; compiler overflow checks |
| **Foundry** | Unit + fuzz + invariant tests + gas-report |
| **Ownable2Step** | Two-step ownership transfer (less risk of a lost owner) |
| **ReentrancyGuardTransient** (EIP-1153) | Cheaper guard than classic storage; requires Cancun |
| **SafeERC20** | Tokens that do not return `bool` or behave oddly |
| **CEI** | Effects before `transfer`; reduces the reentrancy window |
| **Custom errors** | Cheaper, typed reverts vs `require("string")` |
| **No Pausable** | Smaller admin surface; accepted in v1 |
| **No rescue** | Surplus/donations may get stuck; less owner power |

### 2.2 Reward model

| Decision | Why |
|----------|---------|
| **Synthetix / O(1)** style | Scales to many users; lazy accrual |
| `PRECISION = 1e18` | Sufficient for normal rates/wei; truncation dust |
| **Same token** stake == reward | Allowed; in `notify`, `totalSupply` is subtracted from the balance |
| **Pre-funded notify** | Owner transfers tokens to the vault **beforehand**; `notify` only sets rate/period |
| **All-or-nothing** claim | Simplifies state (`rewards[user] = 0`) |
| Only “honest” ERC-20s | No fee-on-transfer / rebase (out of scope) |

### 2.3 Lockup and time

| Decision | Why |
|----------|---------|
| Per-user `unlockTime` | Each `stake` resets `now + lockupDuration` |
| Claim OK during lockup | Locking stake liquidity ≠ locking rewards |
| `withdraw` / `exit` blocked during lockup | Retention policy |
| Times as **`uint64`** (packed) | One storage slot; up to ~year 584e9 |
| `block.timestamp` | Synthetix standard; SWC-116 informational |

### 2.4 State packing

```text
Packed slot:
  _periodFinish | _lastUpdateTime | _rewardsDuration | _lockupDuration
  (uint64 × 4)

Immutables:
  STAKING_TOKEN, REWARDS_TOKEN

Accumulator:
  rewardPerTokenStored, rewardRate, _totalSupply

Per user:
  _balances, userRewardPerTokenPaid, rewards, unlockTime
```

---

## 3. Logic the protocol follows

### 3.1 Core idea (in one sentence)

The contract stores “how much reward per staked token has accumulated so far”. Your `earned` is what is already materialized in `rewards[you]` plus what your stake generated since your last snapshot.

### 3.2 Mental flow

```text
1. Owner puts reward tokens into the vault and calls notifyRewardAmount(R)
   → rewardRate ≈ R / rewardsDuration
   → periodFinish = now + rewardsDuration

2. User does approve + stake(amount)
   → updateReward(user) materializes accumulator + user debt
   → balance and totalSupply go up
   → unlockTime = now + lockupDuration
   → transferFrom stake token

3. Time passes (with totalSupply > 0)
   → the accumulator “grows” in the views (rewardPerToken)
   → no loop and no automatic payout

4. User calls getReward()
   → updateReward → rewards[user] holds the claimable amount
   → rewards = 0; transfer reward to the wallet

5. User withdraw / exit (if lockup expired)
   → updateReward
   → balance / totalSupply go down
   → transfer stake (and in exit also claim)
```

### 3.3 The `updateReward` modifier (the heart)

It runs **before** the body of `stake` / `withdraw` / `getReward` / `exit` / `notify` (in notify with `account = 0`):

1. Computes `rewardPerToken()` (view with the current time).
2. Stores in storage: `rewardPerTokenStored`, `_lastUpdateTime`.
3. If there is a user: `rewards[user] = earned`, `userRewardPerTokenPaid = rpt`.

This way, when stake changes or on claim, nobody “loses” or “steals” someone else's accrual: everyone shares the same global accumulator.

### 3.4 Formulas (summary)

```text
lastTimeRewardApplicable = min(now, periodFinish)

rewardPerToken =
  stored + (deltaTime * rewardRate * 1e18) / totalSupply
  // if totalSupply == 0 → does not advance

earned(user) =
  rewards[user]
  + balance[user] * (rewardPerToken - userRewardPerTokenPaid[user]) / 1e18
```

### 3.5 `notifyRewardAmount` (funding the pot)

- If the period **has already ended**: `rate = reward / duration`.
- If it **is still active**: adds the leftover of the old period and re-prorates over `duration`.
- Checks that the vault holds enough tokens for that rate (`RewardRateTooHigh`).
- If stake == reward: `effective_balance = balance - totalSupply`.

### 3.6 Stake vs reward separation

| Action | What it moves |
|--------|-----------|
| `stake` / `withdraw` | **Stake** token |
| `getReward` | **Reward** token (all accrued) |
| `exit` | Full stake + reward |

You cannot “withdraw 125” by mixing 100 of stake + 25 of reward in a single `withdraw` call.

---

## 4. Gas: what has already been done

Measured in `doc/GAS-EN.md` (before → after):

| Function | Δ avg |
|---------|-------|
| `notifyRewardAmount` | **−32 119** |
| `withdraw` | **−9 199** |
| `exit` | **−8 614** |
| `stake` | **−7 358** |
| `getReward` | **−6 105** |
| Deploy | **+32 493** (acceptable: cheaper user runtime) |

Techniques applied:

- `ReentrancyGuardTransient`
- `uint64` ×4 packing
- Caching of `rewardPerToken` and `msg.sender`
- `unchecked` after subtraction checks
- **Yul** in `rewardPerToken` / `_earned` / min timestamp / packed SLOAD (2026-09-16)

---

## 5. Can gas be improved further?

Yes, but the **residual margin** is small: v1 is already in the typical territory of a well-built StakingRewards. Any extra gain usually costs readability, compatibility, or security.

### 5.1 Plausible improvements (low / medium impact)

| Idea | Pros | Cons |
|------|------|---------|
| Fewer `public` getters / views in the bytecode | Cheaper deploy | Worse DX / less clear ABI |
| Pack more user state (hard) | Fewer SSTOREs | Per-address mappings do not pack easily with each other |
| `calldata` / structs in admin | Cosmetic | Rarely used |
| ~~Assembly / Yul in hot paths~~ | **Applied (2026-09-16)** — see `GAS-EN.md` | Harder to audit; marginal savings |
| Drop `SafeERC20` and assume classic IERC20 | Less code | Breaks “weird” tokens; bad idea |
| `short-circuit` if `amount` does not change earned in edge cases | Micro | Complexity / bugs |

### 5.2 Design improvements (more product than gas)

| Idea | Gas / UX effect |
|------|-----------------|
| Partial claim `getReward(amount)` | + gas and state; better UX |
| Do not reset lockup on every top-up | Different policy; not “cheaper”, just different |
| `permit` / EIP-2612 on stake | Fewer txs (better UX); the pool saves no internal gas |
| Multisig / Timelock owner | Security; not gas |

### 5.3 What is **not** worth “optimizing”

- Removing `updateReward` or CEI → accounting / reentrancy risk.
- Lowering `PRECISION` carelessly → more dust or rounding bugs.
- Loops over users “for clarity” → kills the O(1) model.

### 5.4 Practical reading

For a portfolio / educational production setting, the real bottleneck is no longer “missing unchecked”: it is **ERC-20 transfers** + the **cold SSTORE** of a user's first stake. There the contract can do little without changing the model.

---

## 6. Quick map “where it is in the code”

| Concept | Where |
|----------|--------|
| Accumulator modifier | `updateReward` in `StakingRewards.sol` |
| Math views | `lastTimeRewardApplicable`, `rewardPerToken`, `earned` |
| User mutators | `stake`, `withdraw`, `getReward`, `exit` |
| Admin | `notifyRewardAmount`, `setRewardsDuration`, `setLockupDuration` |
| Gas numbers | `doc/GAS-EN.md` |
| SWC | `doc/SWC-AUDIT-EN.md` |
| Invariants | `doc/04-modelo-matematico-EN.md` |

---

## 7. A short analogy

Picture a **tip jar** that fills at a constant rate while people are sitting at the table:

- The jar does not pay out to each person every second.
- When someone sits down, leaves, or cashes out, the system says: “so far the jar has accumulated X per person-unit; let me update your account”.
- That is the **O(1) accrual** with `rewardPerToken`.

---

*Last aligned with v1 code (Phases 0–7 closed).*
