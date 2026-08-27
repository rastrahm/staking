# Diagrama de clases — Staking & Reward Distribution

Vista estática alineada al código final (Fases 0–7, 2026-08-27). Synthetix-style O(1).

---

## 1. Diagrama de clases (Mermaid)

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

## 2. Responsabilidades

| Tipo | Responsabilidad |
|------|-----------------|
| `IStakingRewards` | Superficie pública estable para tests, scripts y UI |
| `StakingRewards` | Contabilidad O(1), lockup, periodos de reward, CEI |
| OZ Ownable2Step | Admin: notify, durations, ownership 2-step |
| OZ ReentrancyGuardTransient | Blindaje mutators (Cancun / EIP-1153) |
| `SafeERC20` | Transfers ERC-20 sin asumir retorno bool clásico |
| `MockERC20` | Tokens de prueba / demo |
| `StakingClient` | Demo Fase 6 (`frontend/`) |

---

## 3. Estado crítico (modelo Synthetix)

```text
Global:
  rewardPerTokenStored   // acumulador escalado
  rewardRate             // tokens reward / segundo
  lastUpdateTime         // uint64 packed
  periodFinish           // uint64 packed
  totalSupply            // total staked
  rewardsDuration        // uint64 packed
  lockupDuration         // uint64 packed

Por usuario:
  balances[user]
  userRewardPerTokenPaid[user]
  rewards[user]          // pending claimable
  unlockTime[user]       // lockup dinámico
```

### Fórmulas (referencia)

```text
lastTimeRewardApplicable = min(block.timestamp, periodFinish)

rewardPerToken =
  rewardPerTokenStored
  + (deltaTime * rewardRate * PRECISION) / totalSupply
  // si totalSupply == 0 → no avanza el acumulador

earned(user) =
  rewards[user]
  + balances[user] * (rewardPerToken - userRewardPerTokenPaid[user]) / PRECISION
```

`PRECISION`: **`1e18`**. Detalle: [`04-modelo-matematico.md`](./04-modelo-matematico.md).

---

## 4. Layout Solidity (implementado)

1. SPDX + `pragma solidity 0.8.24;`
2. Imports OZ + interfaz
3. Estado (immutables, packing `uint64` ×4, mappings)
4. Modifier `updateReward`
5. Constructor
6. Views → mutators → admin → privados (`_earned`, `_payoutReward`)

---

## 5. Decisiones de diseño (v1)

| Tema | Decisión |
|------|----------|
| `stakingToken == rewardsToken` | Permitido |
| `Pausable` | No en v1 |
| `exit()` | Sí |
| Fee-on-transfer / rebase | No soportado (ERC-20 honestos) |
| `notifyRewardAmount` | Tokens ya en el contrato; solo actualiza contabilidad |
| Guard | `ReentrancyGuardTransient` (no storage clásico) |
