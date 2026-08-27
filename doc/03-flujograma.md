# Flujograma — Staking & Reward Distribution

Diagramas de decisión (sí/no) alineados al código v1. Secuencias: [`02-diagrama-flujo.md`](./02-diagrama-flujo.md). Handoff: [`HANDOFF.md`](./HANDOFF.md).

Orden real de modifiers en mutators de usuario: `nonReentrant` → `updateReward` → cuerpo (checks de amount/lockup).

---

## 1. Flujograma: `stake`

```mermaid
flowchart TD
    A([Inicio: stake amount]) --> B[Lock nonReentrant]
    B --> C[updateReward msg.sender]
    C --> D{amount > 0?}
    D -->|No| E[Revert ZeroAmount]
    E --> Z([Fin error])
    D -->|Sí| F[Effects: totalSupply += amount]
    F --> G[Effects: balances += amount]
    G --> H[Effects: unlockTime = now + lockupDuration]
    H --> I[Interactions: safeTransferFrom]
    I --> J{Transfer OK?}
    J -->|No| K[Revert SafeERC20 / OZ]
    K --> Z
    J -->|Sí| L[Emit Staked]
    L --> M([Fin OK])
```

---

## 2. Flujograma: `updateReward(account)` (modifier)

```mermaid
flowchart TD
    A([Entrada updateReward]) --> B[rpt = rewardPerToken]
    B --> C[rewardPerTokenStored = rpt]
    C --> D[lastUpdateTime = lastTimeRewardApplicable]
    D --> E{account != address 0?}
    E -->|No| F([Continuar función externa])
    E -->|Sí| G[rewards account = _earned account rpt]
    G --> H[userRewardPerTokenPaid = rpt]
    H --> F
```

```mermaid
flowchart TD
    A([rewardPerToken view]) --> B{totalSupply == 0?}
    B -->|Sí| C[Return rewardPerTokenStored]
    B -->|No| D{applicable <= lastUpdateTime?}
    D -->|Sí| C
    D -->|No| E["incr = delta * rewardRate * PRECISION / totalSupply"]
    E --> F[Return stored + incr]
```

---

## 3. Flujograma: `getReward`

```mermaid
flowchart TD
    A([Inicio getReward]) --> B[Lock nonReentrant]
    B --> C[updateReward msg.sender]
    C --> D{rewards user > 0?}
    D -->|No| E([Fin OK sin transfer])
    D -->|Sí| G[Effects: reward = rewards; rewards = 0]
    G --> H[Interactions: safeTransfer rewardsToken]
    H --> I{OK?}
    I -->|No| J[Revert SafeERC20 / OZ]
    J --> Z([Fin error])
    I -->|Sí| K[Emit RewardPaid]
    K --> M([Fin OK])
```

---

## 4. Flujograma: `withdraw`

```mermaid
flowchart TD
    A([Inicio withdraw amount]) --> B[Lock nonReentrant]
    B --> C[updateReward msg.sender]
    C --> D{amount > 0?}
    D -->|No| E[Revert ZeroAmount]
    E --> Z([Fin error])
    D -->|Sí| F{balances >= amount?}
    F -->|No| G[Revert InsufficientStake]
    G --> Z
    F -->|Sí| H{timestamp >= unlockTime?}
    H -->|No| I[Revert LockupActive]
    I --> Z
    H -->|Sí| J[Effects: balances / totalSupply -= amount]
    J --> L[Interactions: safeTransfer stakingToken]
    L --> M{OK?}
    M -->|No| N[Revert SafeERC20 / OZ]
    N --> Z
    M -->|Sí| O[Emit Withdrawn]
    O --> Q([Fin OK])
```

---

## 5. Flujograma: `exit`

```mermaid
flowchart TD
    A([Inicio exit]) --> B[Lock nonReentrant]
    B --> C[updateReward msg.sender]
    C --> D{balance > 0?}
    D -->|No| H[_payoutReward]
    D -->|Sí| E{timestamp >= unlockTime?}
    E -->|No| F[Revert LockupActive]
    F --> Z([Fin error])
    E -->|Sí| G[Effects + safeTransfer stake total]
    G --> H
    H --> I([Fin OK])
```

---

## 6. Flujograma: `notifyRewardAmount`

```mermaid
flowchart TD
    A([Inicio notifyRewardAmount]) --> B{onlyOwner?}
    B -->|No| C[Revert OwnableUnauthorized]
    C --> Z([Fin error])
    B -->|Sí| D[updateReward address 0]
    D --> E{reward > 0?}
    E -->|No| F[Revert ZeroAmount]
    F --> Z
    E -->|Sí| G{timestamp >= periodFinish?}
    G -->|Sí| H["rate = reward / rewardsDuration"]
    G -->|No| I["rate = reward + leftover / duration"]
    H --> J
    I --> J
    J[balance = rewardsToken.balanceOf vault] --> K{stakeToken == rewardToken?}
    K -->|Sí| L["balance efectivo = balance - totalSupply"]
    K -->|No| M[balance efectivo = balance]
    L --> N
    M --> N
    N{"rate <= balance_efectivo / duration?"}
    N -->|No| O[Revert RewardRateTooHigh]
    O --> Z
    N -->|Sí| P[Effects: lastUpdateTime, periodFinish = now + duration]
    P --> Q{periodFinish overflow uint64?}
    Q -->|Sí| R[Revert ZeroAmount]
    R --> Z
    Q -->|No| S[Emit RewardAdded]
    S --> T([Fin OK])
```

> **v1:** no hay `transferFrom` dentro de `notify`. El owner debe haber transferido tokens al vault **antes**.

---

## 7. Flujograma: `setRewardsDuration`

```mermaid
flowchart TD
    A([Inicio setRewardsDuration]) --> B{onlyOwner?}
    B -->|No| C[Revert]
    C --> Z([Fin error])
    B -->|Sí| D{timestamp > periodFinish?}
    D -->|No| E[Revert RewardPeriodActive]
    E --> Z
    D -->|Sí| F{duration > 0 y <= uint64.max?}
    F -->|No| G[Revert ZeroAmount]
    G --> Z
    F -->|Sí| H[Effects: rewardsDuration = duration]
    H --> I[Emit RewardsDurationUpdated]
    I --> J([Fin OK])
```

---

## 8. Flujograma: invariante de vault (tests)

```mermaid
flowchart TD
    A([Handler / invariant run]) --> B[Leer balances en vault]
    B --> C{"rewardsToken.balance >= pendingClaimable?"}
    C -->|No| F[FAIL]
    C -->|Sí| D{"stakingToken.balance >= totalStaked?"}
    D -->|No| F
    D -->|Sí| G[PASS]
    G --> H[Donaciones → balance puede ser >]
```

---

## 9. Flujograma: autorización de fases (histórico)

```mermaid
flowchart TD
    A([Fase N diseñada]) --> B{¿Autorizó Fase N?}
    B -->|No| C[Esperar Autorizo Fase N]
    C --> B
    B -->|Sí| D[Ejecutar]
    D --> E{¿Criterios OK?}
    E -->|No| F[Corregir]
    F --> E
    E -->|Sí| G[Marcar ✅]
    G --> H{¿Fase N+1?}
    H -->|Sí| I[Pedir autorización]
    I --> B
    H -->|No| J([Módulo cerrado 0-7])
```

---

## 10. Leyenda rápida

| Símbolo | Significado |
|---------|-------------|
| Óvalo | Inicio / fin |
| Rectángulo | Proceso o efecto |
| Rombo | Decisión |
| CEI | Checks → Effects → Interactions |
| `updateReward` | Materializa acumulador + deuda usuario O(1) |
| Lockup | `timestamp >= unlockTime` antes de withdraw/exit |
| SafeERC20 | Reverts OZ; `TransferFailed` está en interfaz pero no se usa en impl |
