# Diagrama de clases — Staking & Reward Distribution

Vista estática de tipos, responsabilidades y relaciones. Alineado al plan v1 (Synthetix-style O(1)). Actualizar tras cada fase aprobada si el código diverge.

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
        -IERC20 _stakingToken
        -IERC20 _rewardsToken
        -uint256 rewardPerTokenStored
        -uint256 rewardRate
        -uint256 periodFinish
        -uint256 lastUpdateTime
        -uint256 rewardsDuration
        -uint256 lockupDuration
        -uint256 totalSupply
        -mapping balances
        -mapping userRewardPerTokenPaid
        -mapping rewards
        -mapping unlockTime
        -uint256 PRECISION
        +constructor(stakingToken, rewardsToken, owner)
        -updateReward(account)*
        -_rewardPerToken() uint256
        -_earned(account) uint256
    }

    class Ownable2Step {
        <<OpenZeppelin>>
        +owner()
        +transferOwnership()
        +acceptOwnership()
    }

    class ReentrancyGuard {
        <<OpenZeppelin>>
        +nonReentrant*
    }

    class Pausable {
        <<OpenZeppelin opcional>>
        +pause()
        +unpause()
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
        <<frontend ethers v6 opcional>>
        +connectWallet()
        +approveStake()
        +stake()
        +withdraw()
        +getReward()
        +earned()
    }

    IStakingRewards <|.. StakingRewards
    Ownable2Step <|-- StakingRewards
    ReentrancyGuard <|-- StakingRewards
    Pausable <|-- StakingRewards : opcional
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
| OZ ReentrancyGuard | Blindaje en withdraw/getReward/exit |
| `SafeERC20` | Transfers ERC-20 sin asumir retorno bool clásico |
| `MockERC20` | Tokens de prueba / demo |
| `StakingClient` | Solo si se autoriza Fase 6 |

---

## 3. Estado crítico (modelo Synthetix)

```text
Global:
  rewardPerTokenStored   // acumulador escalado
  rewardRate             // tokens reward / segundo (escalado en uso)
  lastUpdateTime
  periodFinish
  totalSupply            // total staked
  rewardsDuration
  lockupDuration

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

`PRECISION`: `1e18` o `1e36` (fijar en Fase 1).

---

## 4. Layout Solidity esperado

1. SPDX + `pragma solidity 0.8.24;`
2. Imports
3. Errores / eventos (o en interfaz)
4. Constantes (`PRECISION`)
5. Variables de estado (packing consciente)
6. Constructor
7. Modifiers (`updateReward`)
8. Externals → publics → internals → privates
9. Views de math al final o junto a mutators según legibilidad

---

## 5. Notas de diseño abiertas (resolver en Fase 1)

- ¿`stakingToken == rewardsToken` permitido?
- ¿Pausable en v1?
- ¿`exit()` en interfaz mínima?
- ¿Fee-on-transfer: revert documental o medición por delta?
