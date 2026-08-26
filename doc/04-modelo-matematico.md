# Modelo matemático e invariantes — StakingRewards (Fase 1)

Congelado en Fase 1. La implementación (Fase 2+) debe respetar estas definiciones.

---

## 1. Decisiones de diseño v1

| Tema | Decisión |
|------|----------|
| `PRECISION` | **`1e18`** (estilo Synthetix clásico; suficiente con rates/wei normales) |
| `stakingToken == rewardsToken` | **Permitido** |
| `Pausable` | **No** en v1 |
| `exit()` | **Sí** (`withdraw` total + `getReward`) |
| Fee-on-transfer / rebase | **No soportado** — solo ERC-20 honestos |
| `notifyRewardAmount` | Tokens de reward **ya transferidos** al contrato; la fn solo actualiza rate/periodo |

---

## 2. Fórmulas

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

### `updateReward(account)` (materialización)

1. `rewardPerTokenStored = rewardPerToken()`
2. `lastUpdateTime = lastTimeRewardApplicable()`
3. Si `account != address(0)`:
   - `rewards[account] = earned(account)`
   - `userRewardPerTokenPaid[account] = rewardPerTokenStored`

---

## 3. `notifyRewardAmount(reward)`

```text
si timestamp >= periodFinish:
  rewardRate = reward / rewardsDuration
si no:
  leftover = (periodFinish - timestamp) * rewardRate
  rewardRate = (reward + leftover) / rewardsDuration

exigir: rewardRate <= rewardsToken.balanceOf(vault) / rewardsDuration
periodFinish = timestamp + rewardsDuration
lastUpdateTime = timestamp
```

---

## 4. Invariante de vault

### Definiciones

| Símbolo | Significado |
|---------|-------------|
| `totalStaked` | `totalSupply()` = Σ `balanceOf(user)` |
| `pendingClaimable` | Σ `earned(user)` (off-chain / ghost en invariant tests) |
| `unassignedRewards` | Balance de `rewardsToken` en el vault que aún no está en `pendingClaimable` (emisión no liquidada + dust de truncamiento) |

### Reglas

1. **Solvencia de rewards (siempre):**  
   `rewardsToken.balanceOf(vault) >= pendingClaimable`  
   (por truncamiento suele ser `>`; nunca `<`).

2. **Stake token distinto de reward:**  
   `stakingToken.balanceOf(vault) >= totalStaked`  
   El exceso es surplus (donaciones); no forma parte de `totalStaked`.

3. **Mismo token (stake == reward):**  
   `token.balanceOf(vault) >= totalStaked + pendingClaimable`  
   Equivalente a la forma del `.cursorrules`:  
   `balance == totalStaked + unassignedRewards`  
   con `unassignedRewards >= pendingClaimable` (dust ⊆ unassigned).

4. **Forma operativa en handlers Foundry:**  
   tras cada secuencia, assert de (1) y (2)/(3) según configuración del pool.

---

## 5. Prorrateo (misma cuenta, dos lecturas)

Con pot calibrado a tasa T sobre TVL:

- banca: `reward_i = stake_i * T`
- Synthetix: `reward_i = (stake_i / TVL) * (TVL * T)`

Idéntico si el saco = `TVL * T`. Si el saco es otra cifra, manda el pot (prorrateo de “lo que hay”).
