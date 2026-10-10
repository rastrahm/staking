# Flow / sequence diagram — Staking & Reward Distribution

Interaction sequences between **user**, **wallet/frontend** and **StakingRewards** (final v1 code). Complements the [decision flowchart](./03-flujograma-EN.md). Handoff: [`HANDOFF-EN.md`](./HANDOFF-EN.md).

---

## 1. Stake (approve + deposit)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant UI as Frontend / cast (optional)
    participant W as Wallet
    participant T as stakingToken IERC20
    participant S as StakingRewards

    U->>UI: Amount to stake
    UI->>UI: Validate amount > 0
    U->>UI: Confirm
    UI->>W: approve(staking, amount)
    W->>T: approve(staking, amount)
    T-->>W: Approval
    UI->>W: stake(amount)
    W->>S: stake(amount)
    Note over S: updateReward(msg.sender)
    Note over S: Checks: amount > 0
    Note over S: Effects: totalSupply++, balances++, unlockTime
    Note over S: Interactions: safeTransferFrom(user, this, amount)
    alt transfer fails
        S-->>W: revert TransferFailed / SafeERC20
    else OK
        S-->>W: Staked
        W-->>UI: receipt
        UI-->>U: balanceOf / earned updated
    end
```

---

## 2. Time-based accrual (no user txs)

```mermaid
sequenceDiagram
    autonumber
    participant Chain as Blockchain time
    participant S as StakingRewards

    Note over Chain,S: Nobody calls stake/withdraw - the accumulator is lazy
    Chain->>Chain: block.timestamp advances (vm.warp in tests)
    Note over S: lastUpdateTime and rewardPerTokenStored are materialized on the next updateReward
    Note over S: earned(user) view projects reward without writing state
```

---

## 3. Reward claim (`getReward`)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant W as Wallet
    participant S as StakingRewards
    participant R as rewardsToken IERC20

    U->>W: getReward()
    W->>S: getReward()
    Note over S: nonReentrant + updateReward(msg.sender)
    Note over S: Checks: rewards[user] > 0 (or no-op)
    Note over S: Effects: rewards[user] = 0
    Note over S: Interactions: safeTransfer(user, reward)
    alt transfer fails
        S-->>W: revert TransferFailed
    else OK
        S-->>W: RewardPaid
        W-->>U: reward tokens received
    end
```

---

## 4. Unstake (`withdraw`) with lockup

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant W as Wallet
    participant S as StakingRewards
    participant T as stakingToken

    U->>W: withdraw(amount)
    W->>S: withdraw(amount)
    Note over S: nonReentrant + updateReward(msg.sender)
    Note over S: Checks: amount > 0, balance >= amount,<br/>block.timestamp >= unlockTime[user]
    alt lockup active
        S-->>W: revert LockupActive
    else OK
        Note over S: Effects: totalSupply--, balances--
        Note over S: Interactions: safeTransfer(user, amount)
        S-->>W: Withdrawn
    end
```

---

## 5. Full lifecycle (tests: Stake → warp → Claim → Unstake)

```mermaid
sequenceDiagram
    autonumber
    participant Test as Foundry Test
    participant S as StakingRewards
    participant ST as stakingToken
    participant RT as rewardsToken

    Test->>S: notifyRewardAmount(R)
    Test->>ST: approve + stake(A)
    Test->>Test: vm.warp(+T)
    Test->>S: earned(user) view
    Note over Test,S: Assert proportional to A * T * rate
    Test->>S: getReward()
    Test->>RT: balanceOf(user) increased
    Test->>Test: vm.warp until unlock
    Test->>S: withdraw(A)
    Test->>ST: balance restored
```

---

## 6. Period funding (`notifyRewardAmount`)

```mermaid
sequenceDiagram
    autonumber
    actor O as Owner / Distributor
    participant W as Wallet
    participant S as StakingRewards
    participant R as rewardsToken

    O->>R: transfer rewards to the vault (before notify)
    O->>W: notifyRewardAmount(reward)
    W->>S: notifyRewardAmount(reward)
    Note over S: onlyOwner + updateReward(address(0))
    alt period still active
        Note over S: leftover = rate * timeRemaining<br/>new rate = (reward + leftover) / duration
    else period finished
        Note over S: rate = reward / rewardsDuration
    end
    Note over S: If same-token: effective balance = balance - totalSupply<br/>require rate <= effective_balance / duration<br/>otherwise RewardRateTooHigh
    Note over S: Effects: rewardRate, lastUpdateTime, periodFinish
    S-->>W: RewardAdded
```

> **v1:** `notify` does not perform `transferFrom`. The tokens must already be in the contract.

---

## 7. Changing `rewardsDuration` (only outside a period)

```mermaid
sequenceDiagram
    autonumber
    actor O as Owner
    participant S as StakingRewards

    O->>S: setRewardsDuration(newDuration)
    alt block.timestamp <= periodFinish
        S-->>O: revert RewardPeriodActive
    else period inactive
        Note over S: Effects: rewardsDuration = newDuration
        S-->>O: RewardsDurationUpdated
    end
```

---

## 8. Reentrancy attack on claim/withdraw (must fail)

```mermaid
sequenceDiagram
    autonumber
    participant A as AttackerContract
    participant S as StakingRewards

    A->>S: getReward() / withdraw()
    Note over S: Effects: debt/balance already updated
    S->>A: token callback / receive (if malicious token)
    A->>S: reenter getReward/withdraw
    Note over S: nonReentrant OR state already sanitized
    S-->>A: revert
    Note over A: No double-claim / no drain
```
