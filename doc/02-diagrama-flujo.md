# Diagrama de flujo — Staking & Reward Distribution

Secuencias de interacción entre **usuario**, **wallet/frontend** y **StakingRewards**. Complementa el [flujograma de decisiones](./03-flujograma.md).

---

## 1. Stake (approve + deposit)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuario
    participant UI as Frontend / cast (opcional)
    participant W as Wallet
    participant T as stakingToken IERC20
    participant S as StakingRewards

    U->>UI: Monto a stakear
    UI->>UI: Validar amount > 0
    U->>UI: Confirmar
    UI->>W: approve(staking, amount)
    W->>T: approve(staking, amount)
    T-->>W: Approval
    UI->>W: stake(amount)
    W->>S: stake(amount)
    Note over S: updateReward(msg.sender)
    Note over S: Checks: amount > 0
    Note over S: Effects: totalSupply++, balances++, unlockTime
    Note over S: Interactions: safeTransferFrom(user, this, amount)
    alt transfer falla
        S-->>W: revert TransferFailed / SafeERC20
    else OK
        S-->>W: Staked
        W-->>UI: receipt
        UI-->>U: balanceOf / earned actualizados
    end
```

---

## 2. Acumulación temporal (sin txs de usuario)

```mermaid
sequenceDiagram
    autonumber
    participant Chain as Blockchain time
    participant S as StakingRewards

    Note over Chain,S: Nadie llama stake/withdraw; el acumulador es lazy
    Chain->>Chain: block.timestamp avanza (vm.warp en tests)
    Note over S: lastUpdateTime y rewardPerTokenStored<br/>se materializan en el próximo updateReward
    Note over S: earned(user) view proyecta reward sin escribir estado
```

---

## 3. Claim de rewards (`getReward`)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuario
    participant W as Wallet
    participant S as StakingRewards
    participant R as rewardsToken IERC20

    U->>W: getReward()
    W->>S: getReward()
    Note over S: nonReentrant + updateReward(msg.sender)
    Note over S: Checks: rewards[user] > 0 (o no-op)
    Note over S: Effects: rewards[user] = 0
    Note over S: Interactions: safeTransfer(user, reward)
    alt transfer falla
        S-->>W: revert TransferFailed
    else OK
        S-->>W: RewardPaid
        W-->>U: tokens reward recibidos
    end
```

---

## 4. Unstake (`withdraw`) con lockup

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuario
    participant W as Wallet
    participant S as StakingRewards
    participant T as stakingToken

    U->>W: withdraw(amount)
    W->>S: withdraw(amount)
    Note over S: nonReentrant + updateReward(msg.sender)
    Note over S: Checks: amount > 0, balance >= amount,<br/>block.timestamp >= unlockTime[user]
    alt lockup activo
        S-->>W: revert LockupActive
    else OK
        Note over S: Effects: totalSupply--, balances--
        Note over S: Interactions: safeTransfer(user, amount)
        S-->>W: Withdrawn
    end
```

---

## 5. Lifecycle completo (tests: Stake → warp → Claim → Unstake)

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
    Note over Test,S: Assert proporcionales a A * T * rate
    Test->>S: getReward()
    Test->>RT: balanceOf(user) creció
    Test->>Test: vm.warp hasta unlock
    Test->>S: withdraw(A)
    Test->>ST: balance restaurado
```

---

## 6. Funding de periodo (`notifyRewardAmount`)

```mermaid
sequenceDiagram
    autonumber
    actor O as Owner / Distributor
    participant W as Wallet
    participant S as StakingRewards
    participant R as rewardsToken

    O->>R: transfer rewards al contrato (o transferFrom en notify)
    O->>W: notifyRewardAmount(reward)
    W->>S: notifyRewardAmount(reward)
    Note over S: onlyOwner + updateReward(address(0))
    alt periodo aún activo
        Note over S: leftover = rate * timeRemaining<br/>nuevo rate = (reward + leftover) / duration
    else periodo terminado
        Note over S: rate = reward / rewardsDuration
    end
    Note over S: Effects: rewardRate, lastUpdateTime, periodFinish
    S-->>W: RewardAdded
```

---

## 7. Cambio de `rewardsDuration` (solo fuera de periodo)

```mermaid
sequenceDiagram
    autonumber
    actor O as Owner
    participant S as StakingRewards

    O->>S: setRewardsDuration(newDuration)
    alt block.timestamp <= periodFinish
        S-->>O: revert RewardPeriodActive
    else periodo inactivo
        Note over S: Effects: rewardsDuration = newDuration
        S-->>O: RewardsDurationUpdated
    end
```

---

## 8. Ataque de reentrancy en claim/withdraw (debe fallar)

```mermaid
sequenceDiagram
    autonumber
    participant A as AttackerContract
    participant S as StakingRewards

    A->>S: getReward() / withdraw()
    Note over S: Effects: debt/balance ya actualizados
    S->>A: token callback / receive (si token malicioso)
    A->>S: reenter getReward/withdraw
    Note over S: nonReentrant O estado ya saneado
    S-->>A: revert
    Note over A: No double-claim / no drain
```
