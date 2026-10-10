# Guía de comprensión — StakingRewards (v1)

Documento para **entender** el módulo: decisiones técnicas, lógica del protocolo y margen real de mejora de gas.  
Complementa [`04-modelo-matematico-ES.md`](./04-modelo-matematico-ES.md), [`GAS-ES.md`](./GAS-ES.md) y [`HANDOFF-ES.md`](./HANDOFF-ES.md).

---

## 1. Qué problema resuelve

Queremos repartir un **saco de rewards** entre quienes tienen tokens staked, en proporción a su stake y al tiempo, **sin** recorrer la lista de usuarios en cada bloque (eso sería O(n) e inviable).

La solución clásica (Synthetix) es un **acumulador global** (`rewardPerTokenStored`) + una “deuda” por usuario (`userRewardPerTokenPaid` / `rewards`). Cada vez que alguien stakea, retira o claim, se **materializa** lo acumulado hasta ahora y se actualiza su snapshot.

---

## 2. Decisiones técnicas (v1)

### 2.1 Stack y seguridad

| Decisión | Por qué |
|----------|---------|
| Solidity **`0.8.24`** fijo | Sin floating pragma; overflow checks del compilador |
| **Foundry** | Tests unit + fuzz + invariant + gas-report |
| **Ownable2Step** | Transferencia de ownership en 2 pasos (menos riesgo de owner perdido) |
| **ReentrancyGuardTransient** (EIP-1153) | Guard más barato que storage clásico; requiere Cancun |
| **SafeERC20** | Tokens que no devuelven `bool` o se comportan raro |
| **CEI** | Effects antes de `transfer`; reduce ventana de reentrancy |
| **Custom errors** | Reverts más baratos y tipados vs `require("string")` |
| **Sin Pausable** | Menos superficie admin; aceptado en v1 |
| **Sin rescue** | Surplus/donaciones pueden quedar atrapados; menos poder del owner |

### 2.2 Modelo de rewards

| Decisión | Por qué |
|----------|---------|
| Estilo **Synthetix / O(1)** | Escala a muchos usuarios; accrual lazy |
| `PRECISION = 1e18` | Suficiente para rates/wei normales; dust por truncamiento |
| **Same token** stake == reward | Permitido; en `notify` se descuenta `totalSupply` del balance |
| **notify pre-funded** | Owner transfiere tokens al vault **antes**; `notify` solo fija rate/periodo |
| Claim **all-or-nothing** | Simplifica estado (`rewards[user] = 0`) |
| Solo ERC-20 “honestos” | Sin fee-on-transfer / rebase (fuera de alcance) |

### 2.3 Lockup y tiempo

| Decisión | Por qué |
|----------|---------|
| `unlockTime` por usuario | Cada `stake` reinicia `now + lockupDuration` |
| Claim OK en lockup | Retener liquidez de stake ≠ retener reward |
| `withdraw` / `exit` bloqueados en lockup | Política de retención |
| Tiempos en **`uint64`** (packed) | Un slot de storage; hasta ~año 584e9 |
| `block.timestamp` | Estándar Synthetix; SWC-116 informativo |

### 2.4 Empaquetado de estado

```text
Slot empaquetado:
  _periodFinish | _lastUpdateTime | _rewardsDuration | _lockupDuration
  (uint64 × 4)

Immutables:
  STAKING_TOKEN, REWARDS_TOKEN

Acumulador:
  rewardPerTokenStored, rewardRate, _totalSupply

Por usuario:
  _balances, userRewardPerTokenPaid, rewards, unlockTime
```

---

## 3. Lógica que sigue el protocolo

### 3.1 Idea central (en una frase)

El contrato guarda “cuánto reward por token de stake se ha acumulado hasta ahora”. Tu `earned` es lo ya materializado en `rewards[tú]` más lo que tu stake generó desde tu último snapshot.

### 3.2 Flujo mental

```text
1. Owner mete reward tokens al vault y llama notifyRewardAmount(R)
   → rewardRate ≈ R / rewardsDuration
   → periodFinish = now + rewardsDuration

2. Usuario hace approve + stake(amount)
   → updateReward(user) materializa acumulador + deuda del user
   → sube balance y totalSupply
   → unlockTime = now + lockupDuration
   → transferFrom stake token

3. Pasa el tiempo (con totalSupply > 0)
   → el acumulador “crece” en las views (rewardPerToken)
   → no hay loop ni pago automático

4. Usuario getReward()
   → updateReward → rewards[user] tiene el claimable
   → rewards = 0; transfer reward a la wallet

5. Usuario withdraw / exit (si lockup venció)
   → updateReward
   → baja balance / totalSupply
   → transfer stake (y en exit también claim)
```

### 3.3 El modifier `updateReward` (el corazón)

Se ejecuta **antes** del cuerpo de `stake` / `withdraw` / `getReward` / `exit` / `notify` (en notify con `account = 0`):

1. Calcula `rewardPerToken()` (view con el tiempo actual).
2. Guarda en storage: `rewardPerTokenStored`, `_lastUpdateTime`.
3. Si hay usuario: `rewards[user] = earned`, `userRewardPerTokenPaid = rpt`.

Así, al cambiar el stake o al claim, nadie “se pierde” ni “roba” accrual de otro: todos comparten el mismo acumulador global.

### 3.4 Fórmulas (resumen)

```text
lastTimeRewardApplicable = min(now, periodFinish)

rewardPerToken =
  stored + (deltaTime * rewardRate * 1e18) / totalSupply
  // si totalSupply == 0 → no avanza

earned(user) =
  rewards[user]
  + balance[user] * (rewardPerToken - userRewardPerTokenPaid[user]) / 1e18
```

### 3.5 `notifyRewardAmount` (financiar el saco)

- Si el periodo **ya terminó**: `rate = reward / duration`.
- Si **sigue activo**: suma el leftover del periodo viejo y re-prorratea sobre `duration`.
- Chequea que el vault tenga tokens suficientes para ese rate (`RewardRateTooHigh`).
- Si stake == reward: `balance_efectivo = balance - totalSupply`.

### 3.6 Separación stake vs reward

| Acción | Qué mueve |
|--------|-----------|
| `stake` / `withdraw` | Token de **stake** |
| `getReward` | Token de **reward** (todo el acumulado) |
| `exit` | Stake total + reward |

No podés “retirar 125” mezclando 100 de stake + 25 de reward en una sola llamada de `withdraw`.

---

## 4. Gas: qué ya se hizo

Medido en `doc/GAS-ES.md` (antes → después):

| Función | Δ avg |
|---------|-------|
| `notifyRewardAmount` | **−32 119** |
| `withdraw` | **−9 199** |
| `exit` | **−8 614** |
| `stake` | **−7 358** |
| `getReward` | **−6 105** |
| Deploy | **+32 493** (aceptable: runtime de usuarios más barato) |

Técnicas aplicadas:

- `ReentrancyGuardTransient`
- Packing `uint64` ×4
- Cache de `rewardPerToken` y `msg.sender`
- `unchecked` tras checks de resta
- **Yul** en `rewardPerToken` / `_earned` / min timestamp / SLOAD packed (2026-09-16)

---

## 5. ¿Se puede mejorar más el gas?

Sí, pero el **margen residual** es menor: v1 ya está en el terreno típico de un StakingRewards bien hecho. Cualquier ganancia extra suele costar legibilidad, compatibilidad o seguridad.

### 5.1 Mejoras plausibles (bajo / medio impacto)

| Idea | Pros | Contras |
|------|------|---------|
| Menos getters `public` / views en el bytecode | Deploy más barato | Peor DX / ABI menos clara |
| Empaquetar más estado de usuario (difícil) | Menos SSTORE | Mappings por address no se packean fácil entre sí |
| `calldata` / structs en admin | Cosmético | Poco uso |
| ~~Assembler / Yul en hot paths~~ | **Aplicado (2026-09-16)** — ver `GAS-ES.md` | Auditable peor; ahorro marginal |
| Quitar `SafeERC20` y asumir IERC20 clásico | Menos código | Rompe tokens “raros”; mala idea |
| `short-circuit` si `amount` no cambia earned en edge cases | Micro | Complejidad / bugs |

### 5.2 Mejoras de diseño (más producto que gas)

| Idea | Efecto gas / UX |
|------|-----------------|
| Claim parcial `getReward(amount)` | + gas y estado; mejor UX |
| No reiniciar lockup en cada top-up | Otra política; no es “más barato”, es distinto |
| `permit` / EIP-2612 en stake | Menos txs (mejor UX); el pool no ahorra gas interno |
| Multisig / Timelock owner | Seguridad; no gas |

### 5.3 Lo que **no** conviene “optimizar”

- Quitar `updateReward` o CEI → riesgo de contabilidad / reentrancy.
- Bajar `PRECISION` a lo loco → más dust o bugs de redondeo.
- Loops sobre usuarios “para claridad” → mata el modelo O(1).

### 5.4 Lectura práctica

Para un portfolio / producción educativa, el cuello de botella real ya no es “falta unchecked”: es **transfers ERC-20** + **cold SSTORE** del primer stake de un usuario. Ahí el contrato poco puede hacer sin cambiar el modelo.

---

## 6. Mapa rápido “dónde está en el código”

| Concepto | Dónde |
|----------|--------|
| Modifier acumulador | `updateReward` en `StakingRewards.sol` |
| Views math | `lastTimeRewardApplicable`, `rewardPerToken`, `earned` |
| Mutators usuario | `stake`, `withdraw`, `getReward`, `exit` |
| Admin | `notifyRewardAmount`, `setRewardsDuration`, `setLockupDuration` |
| Números de gas | `doc/GAS-ES.md` |
| SWC | `doc/SWC-AUDIT-ES.md` |
| Invariantes | `doc/04-modelo-matematico-ES.md` |

---

## 7. Una analogía corta

Imaginá un **pote de propinas** que se llena a ritmo constante mientras hay gente en la mesa:

- El pote no reparte a cada persona cada segundo.
- Cuando alguien se sienta, se va, o cobra, el sistema dice: “hasta ahora el pote acumula X por persona-unidad; actualizo tu cuenta”.
- Eso es el **accrual O(1)** con `rewardPerToken`.

---

*Última alineación con código v1 (Fases 0–7 cerradas).*
