# Class diagram — Staking & Reward Distribution

Static view aligned with the final code (Phases 0–7, 2026-08-27). Synthetix-style O(1).

---

## 1. Class diagram (Mermaid)

```mermaid
classDiagram
    direction TB

    class IStakingRewards {
        <<interface>>
        +stakingToken() IERC20
        +rewardsToken() IERC20
        +totalSupply() uint256
        +balanceOf(account) uint256
        +lastTimeRewardApplicable() uint256
        +rewardPerToken() uint256
        +earned(account) uint256
        +rewardRate() uint256
        +periodFinish() uint256
        +rewardsDuration() uint256
        +lockupDuration() uint256
        +unlockTime(account) uint256
        +stake(amount)
        +withdraw(amount)
        +getReward()
        +exit()
        +notifyRewardAmount(reward)
        +setRewardsDuration(duration)
        +setLockupDuration(duration)
    }

    class StakingRewards {
        +uint256 PRECISION
        -IERC20 STAKING_TOKEN
        -IERC20 REWARDS_TOKEN
        -uint256 rewardPerTokenStored
        -uint256 rewardRate
        -uint256 _totalSupply
        -uint64 _periodFinish
        -uint64 _lastUpdateTime
        -uint64 _rewardsDuration
        -uint64 _lockupDuration
        -mapping _balances
        -mapping userRewardPerTokenPaid
        -mapping rewards
        -mapping unlockTime
        +constructor(staking, rewards, owner, rewardsDuration, lockupDuration)
        -updateReward(account)*
        -_earned(account, rpt) uint256
        -_payoutReward(account)
    }

    class Ownable2Step {
        <<OpenZeppelin>>
        +owner()
        +transferOwnership()
        +acceptOwnership()
    }

    class ReentrancyGuardTransient {
        <<OpenZeppelin EIP-1153>>
        +nonReentrant*
    }

    class SafeERC20 {
        <<OpenZeppelin library>>
        +safeTransfer()
        +safeTransferFrom()
    }

    class IERC20 {
        <<OpenZeppelin>>
        +transfer()
        +transferFrom()
        +balanceOf()
        +approve()
    }

    class MockERC20 {
        <<test/demo>>
        +mint(to, amount)
    }

    class StakingErrors {
        <<errors>>
        ZeroAmount()
        RewardPeriodActive()
        InsufficientStake()
        TransferFailed()
        LockupActive()
        ZeroAddress()
        RewardRateTooHigh()
    }

    class StakingEvents {
        <<events>>
        Staked(user, amount)
        Withdrawn(user, amount)
        RewardPaid(user, reward)
        RewardAdded(reward)
        RewardsDurationUpdated(newDuration)
        LockupDurationUpdated(newDuration)
    }

    class StakingClient {
        <<frontend Next.js + ethers v6>>
        +connectWallet()
        +stake()
        +withdraw()
        +getReward()
        +exit()
        +earned()
    }

    IStakingRewards <|.. StakingRewards
    Ownable2Step <|-- StakingRewards
    ReentrancyGuardTransient <|-- StakingRewards
    StakingRewards ..> SafeERC20
    StakingRewards ..> IERC20 : staking + rewards
    StakingRewards ..> StakingErrors
    StakingRewards ..> StakingEvents
    MockERC20 --|> IERC20
    StakingClient ..> IStakingRewards
    StakingClient ..> IERC20
```

---

## 2. Responsibilities

| Type | Responsibility |
|------|-----------------|
| `IStakingRewards` | Stable public surface for tests, scripts and UI |
| `StakingRewards` | O(1) accounting, lockup, reward periods, CEI |
| OZ Ownable2Step | Admin: notify, durations, 2-step ownership |
| OZ ReentrancyGuardTransient | Mutator hardening (Cancun / EIP-1153) |
| `SafeERC20` | ERC-20 transfers without assuming the classic bool return |
| `MockERC20` | Test / demo tokens |
| `StakingClient` | Phase 6 demo (`frontend/`) |

---

## 3. Critical state (Synthetix model)

```text
Global:
  rewardPerTokenStored   // scaled accumulator
  rewardRate             // reward tokens / second
  lastUpdateTime         // uint64 packed
  periodFinish           // uint64 packed
  totalSupply            // total staked
  rewardsDuration        // uint64 packed
  lockupDuration         // uint64 packed

Per user:
  balances[user]
  userRewardPerTokenPaid[user]
  rewards[user]          // pending claimable
  unlockTime[user]       // dynamic lockup
```

### Formulas (reference)

```text
lastTimeRewardApplicable = min(block.timestamp, periodFinish)

rewardPerToken =
  rewardPerTokenStored
  + (deltaTime * rewardRate * PRECISION) / totalSupply
  // if totalSupply == 0 → the accumulator does not advance

earned(user) =
  rewards[user]
  + balances[user] * (rewardPerToken - userRewardPerTokenPaid[user]) / PRECISION
```

`PRECISION`: **`1e18`**. Details: [`04-modelo-matematico-EN.md`](./04-modelo-matematico-EN.md).

---

## 4. Solidity layout (implemented)

1. SPDX + `pragma solidity 0.8.24;`
2. OZ imports + interface
3. State (immutables, `uint64` ×4 packing, mappings)
4. `updateReward` modifier
5. Constructor
6. Views → mutators → admin → private (`_earned`, `_payoutReward`)

---

## 5. Design decisions (v1)

| Topic | Decision |
|------|----------|
| `stakingToken == rewardsToken` | Allowed |
| `Pausable` | Not in v1 |
| `exit()` | Yes |
| Fee-on-transfer / rebase | Not supported (honest ERC-20s) |
| `notifyRewardAmount` | Tokens already in the contract; only updates accounting |
| Guard | `ReentrancyGuardTransient` (not classic storage) |
