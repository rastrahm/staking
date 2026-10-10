# Flowchart — Staking & Reward Distribution

Decision diagrams (yes/no) aligned with the v1 code. Sequences: [`02-diagrama-flujo-EN.md`](./02-diagrama-flujo-EN.md). Handoff: [`HANDOFF-EN.md`](./HANDOFF-EN.md).

Actual modifier order in user mutators: `nonReentrant` → `updateReward` → body (amount/lockup checks).

---

## 1. Flowchart: `stake`

```mermaid
flowchart TD
    A([Start: stake amount]) --> B[Lock nonReentrant]
    B --> C[updateReward msg.sender]
    C --> D{amount > 0?}
    D -->|No| E[Revert ZeroAmount]
    E --> Z([End error])
    D -->|Yes| F[Effects: totalSupply += amount]
    F --> G[Effects: balances += amount]
    G --> H[Effects: unlockTime = now + lockupDuration]
    H --> I[Interactions: safeTransferFrom]
    I --> J{Transfer OK?}
    J -->|No| K[Revert SafeERC20 / OZ]
    K --> Z
    J -->|Yes| L[Emit Staked]
    L --> M([End OK])
```

---

## 2. Flowchart: `updateReward(account)` (modifier)

```mermaid
flowchart TD
    A([Enter updateReward]) --> B[rpt = rewardPerToken]
    B --> C[rewardPerTokenStored = rpt]
    C --> D[lastUpdateTime = lastTimeRewardApplicable]
    D --> E{account != address 0?}
    E -->|No| F([Continue external function])
    E -->|Yes| G[rewards account = _earned account rpt]
    G --> H[userRewardPerTokenPaid = rpt]
    H --> F
```

```mermaid
flowchart TD
    A([rewardPerToken view]) --> B{totalSupply == 0?}
    B -->|Yes| C[Return rewardPerTokenStored]
    B -->|No| D{applicable <= lastUpdateTime?}
    D -->|Yes| C
    D -->|No| E["incr = delta * rewardRate * PRECISION / totalSupply"]
    E --> F[Return stored + incr]
```

---

## 3. Flowchart: `getReward`

```mermaid
flowchart TD
    A([Start getReward]) --> B[Lock nonReentrant]
    B --> C[updateReward msg.sender]
    C --> D{rewards user > 0?}
    D -->|No| E([End OK without transfer])
    D -->|Yes| G[Effects: reward = rewards; rewards = 0]
    G --> H[Interactions: safeTransfer rewardsToken]
    H --> I{OK?}
    I -->|No| J[Revert SafeERC20 / OZ]
    J --> Z([End error])
    I -->|Yes| K[Emit RewardPaid]
    K --> M([End OK])
```

---

## 4. Flowchart: `withdraw`

```mermaid
flowchart TD
    A([Start withdraw amount]) --> B[Lock nonReentrant]
    B --> C[updateReward msg.sender]
    C --> D{amount > 0?}
    D -->|No| E[Revert ZeroAmount]
    E --> Z([End error])
    D -->|Yes| F{balances >= amount?}
    F -->|No| G[Revert InsufficientStake]
    G --> Z
    F -->|Yes| H{timestamp >= unlockTime?}
    H -->|No| I[Revert LockupActive]
    I --> Z
    H -->|Yes| J[Effects: balances / totalSupply -= amount]
    J --> L[Interactions: safeTransfer stakingToken]
    L --> M{OK?}
    M -->|No| N[Revert SafeERC20 / OZ]
    N --> Z
    M -->|Yes| O[Emit Withdrawn]
    O --> Q([End OK])
```

---

## 5. Flowchart: `exit`

```mermaid
flowchart TD
    A([Start exit]) --> B[Lock nonReentrant]
    B --> C[updateReward msg.sender]
    C --> D{balance > 0?}
    D -->|No| H[_payoutReward]
    D -->|Yes| E{timestamp >= unlockTime?}
    E -->|No| F[Revert LockupActive]
    F --> Z([End error])
    E -->|Yes| G[Effects + safeTransfer full stake]
    G --> H
    H --> I([End OK])
```

---

## 6. Flowchart: `notifyRewardAmount`

```mermaid
flowchart TD
    A([Start notifyRewardAmount]) --> B{onlyOwner?}
    B -->|No| C[Revert OwnableUnauthorized]
    C --> Z([End error])
    B -->|Yes| D[updateReward address 0]
    D --> E{reward > 0?}
    E -->|No| F[Revert ZeroAmount]
    F --> Z
    E -->|Yes| G{timestamp >= periodFinish?}
    G -->|Yes| H["rate = reward / rewardsDuration"]
    G -->|No| I["rate = reward + leftover / duration"]
    H --> J
    I --> J
    J[balance = rewardsToken.balanceOf vault] --> K{stakeToken == rewardToken?}
    K -->|Yes| L["effective balance = balance - totalSupply"]
    K -->|No| M[effective balance = balance]
    L --> N
    M --> N
    N{"rate <= effective_balance / duration?"}
    N -->|No| O[Revert RewardRateTooHigh]
    O --> Z
    N -->|Yes| P[Effects: lastUpdateTime, periodFinish = now + duration]
    P --> Q{periodFinish overflow uint64?}
    Q -->|Yes| R[Revert ZeroAmount]
    R --> Z
    Q -->|No| S[Emit RewardAdded]
    S --> T([End OK])
```

> **v1:** there is no `transferFrom` inside `notify`. The owner must have transferred tokens to the vault **beforehand**.

---

## 7. Flowchart: `setRewardsDuration`

```mermaid
flowchart TD
    A([Start setRewardsDuration]) --> B{onlyOwner?}
    B -->|No| C[Revert]
    C --> Z([End error])
    B -->|Yes| D{timestamp > periodFinish?}
    D -->|No| E[Revert RewardPeriodActive]
    E --> Z
    D -->|Yes| F{duration > 0 and <= uint64.max?}
    F -->|No| G[Revert ZeroAmount]
    G --> Z
    F -->|Yes| H[Effects: rewardsDuration = duration]
    H --> I[Emit RewardsDurationUpdated]
    I --> J([End OK])
```

---

## 8. Flowchart: vault invariant (tests)

```mermaid
flowchart TD
    A([Handler / invariant run]) --> B[Read vault balances]
    B --> C{"rewardsToken.balance >= pendingClaimable?"}
    C -->|No| F[FAIL]
    C -->|Yes| D{"stakingToken.balance >= totalStaked?"}
    D -->|No| F
    D -->|Yes| G[PASS]
    G --> H[Donations → balance may be >]
```

---

## 9. Flowchart: phase authorization (historical)

```mermaid
flowchart TD
    A([Phase N designed]) --> B{Phase N authorized?}
    B -->|No| C[Wait for Authorize Phase N]
    C --> B
    B -->|Yes| D[Execute]
    D --> E{Criteria OK?}
    E -->|No| F[Fix]
    F --> E
    E -->|Yes| G[Mark ✅]
    G --> H{Phase N+1?}
    H -->|Yes| I[Request authorization]
    I --> B
    H -->|No| J([Module closed 0-7])
```

---

## 10. Quick legend

| Symbol | Meaning |
|---------|-------------|
| Oval | Start / end |
| Rectangle | Process or effect |
| Diamond | Decision |
| CEI | Checks → Effects → Interactions |
| `updateReward` | Materializes accumulator + user debt O(1) |
| Lockup | `timestamp >= unlockTime` before withdraw/exit |
| SafeERC20 | OZ reverts; `TransferFailed` is in the interface but not used in the impl |
