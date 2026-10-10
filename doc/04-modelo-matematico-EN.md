# Mathematical model and invariants — StakingRewards

Canonical reference for implementation and handoff (Phases 1–7). The code must respect these definitions.

---

## 1. v1 design decisions

| Topic | Decision |
|------|----------|
| `PRECISION` | **`1e18`** (classic Synthetix style; sufficient with normal rates/wei) |
| `stakingToken == rewardsToken` | **Allowed** |
| `Pausable` | **No** in v1 |
| `exit()` | **Yes** (full `withdraw` + `getReward`) |
| Fee-on-transfer / rebase | **Not supported** — only honest ERC-20s |
| `notifyRewardAmount` | Reward tokens **already transferred** to the contract; the fn only updates rate/period |
| Lockup | Each stake resets `unlockTime = now + lockupDuration`. `setLockupDuration` does not touch existing unlocks. Claim OK during lockup; withdraw/exit not. |

---

## 2. Formulas

```text
PRECISION = 1e18

lastTimeRewardApplicable =
  min(block.timestamp, periodFinish)

rewardPerToken =
  if totalSupply == 0:
      rewardPerTokenStored
  else:
      rewardPerTokenStored
        + (lastTimeRewardApplicable - lastUpdateTime)
          * rewardRate
          * PRECISION
          / totalSupply

earned(account) =
  rewards[account]
    + balanceOf(account)
      * (rewardPerToken - userRewardPerTokenPaid[account])
      / PRECISION
```

### `updateReward(account)` (materialization)

1. `rewardPerTokenStored = rewardPerToken()`
2. `lastUpdateTime = lastTimeRewardApplicable()`
3. If `account != address(0)`:
   - `rewards[account] = earned(account)`
   - `userRewardPerTokenPaid[account] = rewardPerTokenStored`

---

## 3. `notifyRewardAmount(reward)`

```text
if timestamp >= periodFinish:
  rewardRate = reward / rewardsDuration
else:
  leftover = (periodFinish - timestamp) * rewardRate
  rewardRate = (reward + leftover) / rewardsDuration

balance = rewardsToken.balanceOf(vault)
if stakingToken == rewardsToken:
  balance = balance - totalSupply   // do not count stake as reward

require: rewardRate <= balance / rewardsDuration
  otherwise revert RewardRateTooHigh

periodFinish = timestamp + rewardsDuration   // uint64 overflow → ZeroAmount
lastUpdateTime = timestamp
```

Reward tokens must **already** be in the vault (there is no `transferFrom` in `notify`).

---

## 4. Vault invariant

### Definitions

| Symbol | Meaning |
|---------|-------------|
| `totalStaked` | `totalSupply()` = Σ `balanceOf(user)` |
| `pendingClaimable` | Σ `earned(user)` (off-chain / ghost in invariant tests) |
| `unassignedRewards` | `rewardsToken` balance in the vault not yet in `pendingClaimable` (unsettled emission + truncation dust) |

### Rules

1. **Reward solvency (always):**  
   `rewardsToken.balanceOf(vault) >= pendingClaimable`  
   (due to truncation it is usually `>`; never `<`).

2. **Stake token different from reward:**  
   `stakingToken.balanceOf(vault) >= totalStaked`  
   The excess is surplus (donations); it is not part of `totalStaked`.

3. **Same token (stake == reward):**  
   `token.balanceOf(vault) >= totalStaked + pendingClaimable`  
   With `unassignedRewards = balance - totalStaked` (may include dust and surplus):  
   `unassignedRewards >= pendingClaimable`. Donations → strict `>` is OK.

4. **Operational form in Foundry handlers:**  
   after each sequence, assert (1) and (2)/(3) depending on the pool configuration.

---

## 5. Pro-rata (same math, two readings)

With a pot calibrated to rate T over TVL:

- banking: `reward_i = stake_i * T`
- Synthetix: `reward_i = (stake_i / TVL) * (TVL * T)`

Identical if the pot = `TVL * T`. If the pot is a different figure, the pot rules (pro-rata of “what is there”).
