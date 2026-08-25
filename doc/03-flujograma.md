# Flujograma — Staking & Reward Distribution

Diagramas de decisión (sí/no) para operaciones críticas. Ver también el [diagrama de flujo / secuencias](./02-diagrama-flujo.md).

---

## 1. Flujograma general: `stake`

```mermaid
flowchart TD
    A([Inicio: stake amount]) --> B{amount > 0?}
    B -->|No| C[Revert ZeroAmount]
    C --> Z([Fin error])
    B -->|Sí| D[updateReward msg.sender]
    D --> E[Actualizar rewardPerTokenStored / rewards / paid]
    E --> F[Effects: balances += amount]
    F --> G[Effects: totalSupply += amount]
    G --> H[Effects: unlockTime = now + lockupDuration]
    H --> I[Interactions: safeTransferFrom]
    I --> J{Transfer OK?}
    J -->|No| K[Revert TransferFailed / SafeERC20]
    K --> Z
    J -->|Sí| L[Emit Staked]
    L --> M([Fin OK])
```

---

## 2. Flujograma: `updateReward(account)` (modifier)

```mermaid
flowchart TD
    A([Entrada updateReward]) --> B[rewardPerTokenStored = rewardPerToken]
    B --> C[lastUpdateTime = lastTimeRewardApplicable]
    C --> D{account != address 0?}
    D -->|No| E([Continuar función externa])
    D -->|Sí| F[rewards account = earned account]
    F --> G[userRewardPerTokenPaid = rewardPerTokenStored]
    G --> E
```

```mermaid
flowchart TD
    A([rewardPerToken view/internal]) --> B{totalSupply == 0?}
    B -->|Sí| C[Return rewardPerTokenStored]
    B -->|No| D[delta = lastTimeRewardApplicable - lastUpdateTime]
    D --> E["incr = delta * rewardRate * PRECISION / totalSupply"]
    E --> F[Return stored + incr]
```

---

## 3. Flujograma: `getReward`

```mermaid
flowchart TD
    A([Inicio getReward]) --> B[Lock nonReentrant]
    B --> C[updateReward msg.sender]
    C --> D{rewards user > 0?}
    D -->|No| E[Unlock / no-op]
    E --> F([Fin OK sin transfer])
    D -->|Sí| G[Effects: reward = rewards; rewards = 0]
    G --> H[Interactions: safeTransfer rewardsToken]
    H --> I{OK?}
    I -->|No| J[Revert TransferFailed]
    J --> Z([Fin error])
    I -->|Sí| K[Emit RewardPaid]
    K --> L[Unlock]
    L --> M([Fin OK])
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
    H -->|Sí| J[Effects: balances -= amount]
    J --> K[Effects: totalSupply -= amount]
    K --> L[Interactions: safeTransfer stakingToken]
    L --> M{OK?}
    M -->|No| N[Revert TransferFailed]
    N --> Z
    M -->|Sí| O[Emit Withdrawn]
    O --> P[Unlock]
    P --> Q([Fin OK])
```

---

## 5. Flujograma: `notifyRewardAmount`

```mermaid
flowchart TD
    A([Inicio notifyRewardAmount]) --> B{msg.sender owner/distributor?}
    B -->|No| C[Revert OwnableUnauthorized]
    C --> Z([Fin error])
    B -->|Sí| D[updateReward address 0]
    D --> E{timestamp >= periodFinish?}
    E -->|Sí| F["rate = reward / rewardsDuration"]
    E -->|No| G["leftover = remaining * rate"]
    G --> H["rate = reward + leftover / duration"]
    F --> I[Effects: rewardRate, lastUpdateTime, periodFinish]
    H --> I
    I --> J{¿Tokens reward ya en contrato?}
    J -->|No| K[transferFrom distributor o revert]
    K --> L{OK?}
    L -->|No| Z
    L -->|Sí| M[Emit RewardAdded]
    J -->|Sí| M
    M --> N([Fin OK])
```

---

## 6. Flujograma: `setRewardsDuration`

```mermaid
flowchart TD
    A([Inicio setRewardsDuration]) --> B{onlyOwner?}
    B -->|No| C[Revert]
    C --> Z([Fin error])
    B -->|Sí| D{timestamp > periodFinish?}
    D -->|No| E[Revert RewardPeriodActive]
    E --> Z
    D -->|Sí| F{newDuration > 0?}
    F -->|No| G[Revert ZeroAmount / InvalidDuration]
    G --> Z
    F -->|Sí| H[Effects: rewardsDuration = newDuration]
    H --> I[Emit RewardsDurationUpdated]
    I --> J([Fin OK])
```

---

## 7. Flujograma: invariante de vault (tests)

```mermaid
flowchart TD
    A([Handler / invariant run]) --> B[Leer balance stakingToken en vault]
    B --> C[Leer totalSupply / totalStaked]
    C --> D[Leer unassignedRewards según definición Fase 1]
    D --> E{"balance == totalStaked + unassigned?"}
    E -->|No| F[FAIL invariante]
    E -->|Sí| G[PASS]
    G --> H[Opcional: rewardsToken solvencia vs suma earned]
```

---

## 8. Flujograma: autorización de fases (proceso de desarrollo)

```mermaid
flowchart TD
    A([Fase N diseñada en doc]) --> B{¿Responsable autorizó Fase N?}
    B -->|No| C[Esperar: Autorizo Fase N]
    C --> B
    B -->|Sí| D[Ejecutar tareas de la fase]
    D --> E{¿Criterios de aceptación OK?}
    E -->|No| F[Corregir / re-test]
    F --> E
    E -->|Sí| G[Marcar Fase N ✅ + fecha]
    G --> H{¿Hay Fase N+1?}
    H -->|Sí| I[Pedir autorización Fase N+1]
    I --> B
    H -->|No| J([Módulo cerrado])
```

---

## 9. Leyenda rápida

| Símbolo | Significado |
|---------|-------------|
| Óvalo | Inicio / fin |
| Rectángulo | Proceso o efecto de estado |
| Rombo | Decisión |
| CEI | Checks → Effects → Interactions |
| `updateReward` | Materializa acumulador global y deuda del usuario en O(1) |
| Lockup | `block.timestamp >= unlockTime[user]` antes de withdraw |
