# Plan de implementación — Staking & Reward Distribution (Módulo 03)

Documento maestro del módulo. Define fases, entregables, criterios de aceptación y el **protocolo de autorización** obligatorio antes de cada avance.

---

## Protocolo de autorización

> **Regla dura:** cada fase debe ser revisada y **aprobada explícitamente** por el responsable del proyecto antes de iniciar la siguiente.  
> No se escribe código de implementación de una fase sin esa confirmación.  
> Al cerrar una fase: marcar estado → `✅ Aprobada` + fecha; solo entonces se puede pedir arranque de la siguiente.

| Estado | Significado |
|--------|-------------|
| 🔒 Pendiente de autorización | Diseño listo; **no ejecutar** hasta OK |
| 🔄 En curso | Autorizada y en desarrollo |
| ✅ Aprobada | Cerrada; se puede proponer la siguiente |
| ⏸️ Pausada | Bloqueada por decisión externa |

**Cómo autorizar:** responde en el chat con algo como `Autorizo Fase N` (o rechaza con cambios concretos).

---

## 1. Objetivo del módulo

Construir un **protocolo de staking con distribución proporcional de rewards en O(1)** que:

- Use el algoritmo estilo **Synthetix** (`rewardPerTokenStored` + `userRewardPerTokenPaid` + `rewards`).
- Acumule rewards con `lastUpdateTime` y `rewardRate` **sin loops** sobre usuarios.
- Maneje precisión interna con scaling (`1e18` o `1e36`).
- Soporte **periodos de reward** y **lockups dinámicos** (unstake sujeto a unlock).
- Maneje tokens ERC-20 de stake y reward de forma segura (`SafeERC20` / checks explícitos).
- Aplique **CEI**, custom errors y NatSpec.
- Incluya suite Foundry: unit + `vm.warp` + fuzz + invariante  
  `balance(vault) == totalStaked + unassignedRewards` (según modelo de tokens).
- (Opcional v1.1) Frontend Next.js + ethers.js v6 para demo.

---

## 2. Stack acordado

| Capa | Tecnología | Notas |
|------|------------|--------|
| Contratos | Solidity `0.8.24` (pragma fijo) | Sin floating pragma |
| Tooling | Foundry (`forge`, `cast`, `anvil`) | Unit, fuzz, invariant, gas |
| Librerías | OpenZeppelin v5.x | `SafeERC20`, `Ownable2Step`, `ReentrancyGuard`, `Pausable` según diseño |
| Modelo matemático | Accumulator Synthetix-style | O(1) por usuario |
| Frontend (fase opcional) | Next.js App Router + TS + ethers v6 + Zod | Reglas `nextjs.cursorrules` |
| Tests UI | Vitest + RTL | Solo si se autoriza fase frontend |

**Fuera de alcance en v1 (salvo autorización explícita):** multi-reward tokens, veToken/boost, liquid staking, bridges, The Graph, mainnet production hardening.

---

## 3. Arquitectura lógica (resumen)

```
Usuario (MetaMask / cast)
        │
        ▼
[Opcional] Next.js + ethers v6  ──RPC──►  Anvil / Testnet
        │                                      │
        └──────── ABI + address ───────────────┤
                                               ▼
                                    StakingRewards (core)
                          ┌────────────┼────────────────┐
                          ▼            ▼                ▼
                   balances[]    reward math      lockup / period
                   totalSupply   rewardPerToken   finishAt / unlock
                          │            │
                          ▼            ▼
                   stakingToken   rewardsToken (IERC20)
```

Diagramas:

- [Diagrama de clases](./01-diagrama-clases.md)
- [Diagrama de flujo](./02-diagrama-flujo.md)
- [Flujograma](./03-flujograma.md)

---

## 4. Estructura de repositorio prevista

```
03-staking/
├── .cursorrules
├── doc/                              # Plan y diagramas (este directorio)
├── foundry.toml
├── remappings.txt
├── src/
│   ├── interfaces/IStakingRewards.sol
│   ├── StakingRewards.sol
│   └── mocks/MockERC20.sol           # solo tests / demo
├── script/
│   └── Deploy.s.sol
├── test/
│   ├── unit/StakingRewards.t.sol
│   ├── fuzz/StakingRewards.fuzz.t.sol
│   ├── invariant/StakingRewards.invariant.t.sol
│   └── attack/                     # reentrancy / griefing si aplica
└── frontend/                       # solo si se autoriza fase UI
    ├── app/
    ├── components/
    ├── lib/
    └── abi/
```

---

## 5. Superficie on-chain prevista (v1)

| Función / pieza | Rol |
|-----------------|-----|
| `stake(amount)` | Depositar staking token; `updateReward(msg.sender)` |
| `withdraw(amount)` | Retirar stake (respetando lockup); `updateReward` |
| `getReward()` | Claim rewards acumulados; `updateReward` |
| `exit()` | `withdraw` + `getReward` (opcional) |
| `notifyRewardAmount(reward)` | Owner/distributor financia periodo; ajusta `rewardRate` |
| `setRewardsDuration(duration)` | Solo si periodo no activo (`RewardPeriodActive`) |
| `setLockupDuration(duration)` | Lockup dinámico para nuevos stakes / política acordada |
| Views | `earned`, `rewardPerToken`, `balanceOf`, `totalSupply`, `lastTimeRewardApplicable` |
| Modifier | `updateReward(account)` en mutators de usuario |

### Errores custom (mínimo según `.cursorrules`)

- `ZeroAmount()`
- `RewardPeriodActive()`
- `InsufficientStake()`
- `TransferFailed()`
- (+ adicionales documentados: `LockupActive()`, `ZeroAddress()`, etc. si el diseño lo exige)

### Invariante de vault

```text
balanceOf(stakingToken, vault) >= totalStaked
balanceOf(rewardsToken, vault) >= rewards pendientes + residual no asignado
# Forma acordada en Fase 1:
# vault_balance_relevant == totalStaked + unassignedRewards
```

---

## 6. Fases de implementación

### Resumen

| Fase | Nombre | Estado |
|------|--------|--------|
| 0 | Bootstrap Foundry + docs | ✅ Aprobada (2026-08-26) |
| 1 | Diseño on-chain: interfaces, errores, modelo math + tests rojos | ✅ Aprobada (2026-08-26) |
| 2 | Implementación core O(1) + unit tests (`vm.warp`) | 🔒 Pendiente de autorización |
| 3 | Lockup dinámico + `notifyRewardAmount` / duración | 🔒 Pendiente de autorización |
| 4 | Fuzz + invariantes + ataques / gas report | 🔒 Pendiente de autorización |
| 5 | Scripts deploy + ABI | 🔒 Pendiente de autorización |
| 6 | Frontend demo (opcional) | 🔒 Pendiente de autorización |
| 7 | Docs finales, handoff, alineación diagramas | 🔒 Pendiente de autorización |

---

### Fase 0 — Bootstrap del módulo

**Estado:** ✅ Aprobada — 2026-08-26  
**Duración estimada:** 0.5 día

#### Objetivo

Inicializar Foundry, pinnear OZ v5, fijar `0.8.24`, dejar layout listo.

#### Tareas

1. `forge init` (respetando `.gitignore` del monorepo).
2. `foundry.toml`: Solidity `0.8.24`, fuzz runs ≥ 1000, optimizer.
3. Instalar OpenZeppelin Contracts v5 + forge-std.
4. Remappings; estructura `src/`, `test/`, `script/`, `doc/`.
5. Verificar `forge build`.

#### Criterios de aceptación

- [x] Compila sin errores.
- [x] Pragma fijo `0.8.24`.
- [x] Dependencias OZ instaladas.
- [x] `doc/` presente y referenciado.

#### Resultado

- Foundry `1.4.3-stable` con `forge init --no-git --force`.
- `foundry.toml`: `solc = 0.8.24`, `evm_version = cancun`, fuzz `runs = 1000`, invariant configurado.
- Dependencias: `forge-std` + `openzeppelin-contracts@v5.0.2` (submódulos).
- Placeholder: `src/StakingRewards.sol`, `test/StakingRewards.t.sol`, `script/Deploy.s.sol`.
- Layout: `src/interfaces/`, `src/mocks/`, `test/{unit,fuzz,invariant}/`, `doc/`, `.env.example`, `README.md`.
- `forge build` OK; `forge test` → 1 passed (`test_moduleId`).
- Nota: usar `export PATH="$HOME/.foundry/bin:$PATH"` (el `forge` de npm choca con Foundry).

#### Aprobación

- [x] Autorizada para ejecutar  
- [x] Completada y revisada → ✅ 2026-08-26

> Responde cuando quieras iniciar la **Fase 1**: `Autorizo Fase 1`

---

### Fase 1 — Diseño on-chain + TDD (tests primero)

**Estado:** ✅ Aprobada — 2026-08-26  
**Duración estimada:** 1 día  
**Depende de:** Fase 0 ✅

#### Objetivo

Congelar interfaz, errores, eventos y fórmulas; escribir tests que fallen / esqueleto antes de lógica completa.

#### Tareas

1. `IStakingRewards.sol` con NatSpec completo.
2. Custom errors + events (`Staked`, `Withdrawn`, `RewardPaid`, `RewardAdded`, …).
3. Documentar fórmulas:
   - `rewardPerToken`
   - `earned(account)`
   - `lastTimeRewardApplicable`
4. Definir significado exacto de `unassignedRewards` / invariante.
5. Esqueleto `StakingRewards.sol` + suite unitaria inicial (asserts esperados).

#### Criterios de aceptación

- [x] Interfaces compilables.
- [x] Solo custom errors (sin `require` strings).
- [x] Tests unitarios escritos para lifecycle Stake → warp → Claim → Unstake (rojos hasta Fase 2).
- [x] Fórmulas escritas en NatSpec / `doc/04-modelo-matematico.md`.

#### Resultado

- `src/interfaces/IStakingRewards.sol` — events, errors, views, mutators, NatSpec + fórmulas.
- `src/StakingRewards.sol` — esqueleto Ownable2Step + ReentrancyGuard; views math; mutators → `NotImplemented`.
- `src/mocks/MockERC20.sol` — mint para tests.
- `test/StakingRewards.t.sol` — 7 tests verdes (constructor, views, NotImplemented).
- `test/unit/StakingRewards.lifecycle.t.sol` — 2 tests **rojos** TDD (lifecycle + prorrateo 2 stakers).
- `doc/04-modelo-matematico.md` — PRECISION `1e18`, invariante, decisiones v1.
- Decisiones: same token OK; sin Pausable; `exit()` sí; sin fee-on-transfer; notify con tokens ya en vault.

#### Aprobación

- [x] Autorizada para ejecutar  
- [x] Completada y revisada → ✅ 2026-08-26

> Responde cuando quieras iniciar la **Fase 2**: `Autorizo Fase 2`

---

### Fase 2 — Implementación core O(1) + unit tests

**Estado:** 🔒 Pendiente de autorización  
**Duración estimada:** 1–2 días  
**Depende de:** Fase 1 ✅

#### Objetivo

Implementar accumulator + `updateReward` + stake / withdraw / getReward con CEI y SafeERC20.

#### Tareas

1. Estado: `rewardPerTokenStored`, `userRewardPerTokenPaid`, `rewards`, `balances`, `totalSupply`, `rewardRate`, `periodFinish`, `lastUpdateTime`.
2. Modifier `updateReward(address account)`.
3. `stake` / `withdraw` / `getReward` con CEI.
4. Scaling factor (`1e18` o `1e36`) justificado en NatSpec.
5. Unit tests con `vm.warp` / `vm.roll` para accrual exacto.
6. Casos: zero amount, insufficient stake, transfer fail.

#### Criterios de aceptación

- [ ] Cero loops sobre arrays de usuarios.
- [ ] Lifecycle unitario verde.
- [ ] Rewards proporcionales a stake × tiempo (casos con 1 y 2 stakers).
- [ ] NatSpec en públicas/externas.

#### Aprobación

- [ ] Autorizada para ejecutar  
- [ ] Completada y revisada → ✅ + fecha

> **No iniciar Fase 2 sin:** `Autorizo Fase 2`

---

### Fase 3 — Lockup dinámico + funding de rewards

**Estado:** 🔒 Pendiente de autorización  
**Duración estimada:** 1 día  
**Depende de:** Fase 2 ✅

#### Objetivo

Periodos de reward (`notifyRewardAmount`, `setRewardsDuration`) y lockups dinámicos.

#### Tareas

1. `notifyRewardAmount` (solo rol autorizado); leftover + nuevo rate.
2. `setRewardsDuration` → revert `RewardPeriodActive` si periodo vivo.
3. Política de lockup: `unlockTime[user]` / duración global configurable.
4. `withdraw` respeta lockup → error dedicado si aplica.
5. Tests de borde: notify mid-period, duration change fuera de periodo, unlock exacto con warp.

#### Criterios de aceptación

- [ ] No se puede acortar/cambiar duration con periodo activo.
- [ ] Unstake bloqueado hasta unlock.
- [ ] Funding no rompe contabilidad de rewards ya earned.

#### Aprobación

- [ ] Autorizada para ejecutar  
- [ ] Completada y revisada → ✅ + fecha

> **No iniciar Fase 3 sin:** `Autorizo Fase 3`

---

### Fase 4 — Fuzz, invariantes, ataques, gas

**Estado:** 🔒 Pendiente de autorización  
**Duración estimada:** 1–2 días  
**Depende de:** Fase 3 ✅

#### Objetivo

Endurecer propiedades matemáticas y de seguridad.

#### Tareas

1. Fuzz: montos, duraciones, multi-user simulado.
2. Invariant: `totalStaked + unassignedRewards` vs balances de vault.
3. Ataque reentrancy en `getReward` / `withdraw` (debe fallar).
4. `forge test --gas-report` y notas de tradeoffs.
5. Cobertura de ramas de paths explícitos.

#### Criterios de aceptación

- [ ] Fuzz ≥ 1000 runs sin rotura de invariante.
- [ ] Reentrancy no drena.
- [ ] Gas report baseline documentado (puede vivir en `doc/GAS.md` si se autoriza crear ese archivo).

#### Aprobación

- [ ] Autorizada para ejecutar  
- [ ] Completada y revisada → ✅ + fecha

> **No iniciar Fase 4 sin:** `Autorizo Fase 4`

---

### Fase 5 — Deploy scripts + ABI

**Estado:** 🔒 Pendiente de autorización  
**Duración estimada:** 0.5 día  
**Depende de:** Fase 4 ✅

#### Objetivo

Deploy reproducible en Anvil/testnet y export de ABI para UI.

#### Tareas

1. `Deploy.s.sol` (staking token, rewards token, pool, notify inicial opcional).
2. `.env.example` sin secretos.
3. Export ABI → `frontend/abi/` o `doc/abi/` según alcance UI.
4. Playbook Anvil en README/HANDOFF (cuando exista).

#### Criterios de aceptación

- [ ] Deploy script verde en Anvil.
- [ ] Addresses + ABI documentados.

#### Aprobación

- [ ] Autorizada para ejecutar  
- [ ] Completada y revisada → ✅ + fecha

> **No iniciar Fase 5 sin:** `Autorizo Fase 5`

---

### Fase 6 — Frontend demo (opcional)

**Estado:** 🔒 Pendiente de autorización  
**Duración estimada:** 2–3 días  
**Depende de:** Fase 5 ✅

#### Objetivo

Demo Next.js: conectar wallet, stake, claim, unstake, ver `earned`.

#### Tareas

1. App Router; `'use client'` / `'use server'` explícitos.
2. ethers v6 + Zod + JSDoc.
3. Flujos: approve + stake, getReward, withdraw (lockup UX).
4. Vitest + RTL (TDD interacción).
5. `.env.example` con `NEXT_PUBLIC_*`.

#### Criterios de aceptación

- [ ] Flujo feliz documentado.
- [ ] `next build` OK.
- [ ] Tests UI mínimos verdes.

#### Aprobación

- [ ] Autorizada para ejecutar (o **omitida** por decisión)  
- [ ] Completada / omitida → ✅ o ⏸️ + fecha

> **No iniciar Fase 6 sin:** `Autorizo Fase 6` (o `Omitir Fase 6`)

---

### Fase 7 — Docs finales y handoff

**Estado:** 🔒 Pendiente de autorización  
**Duración estimada:** 0.5–1 día  
**Depende de:** Fase 5 ✅ (y Fase 6 si no se omitió)

#### Objetivo

Alinear diagramas con código final; README usable por un tercero.

#### Tareas

1. README del módulo.
2. Actualizar diagramas si hubo desviaciones.
3. HANDOFF / limitaciones / mejoras (si se autorizan esos archivos).
4. Checklist Definition of Done global.

#### Criterios de aceptación

- [ ] `doc/` coherente con implementación.
- [ ] Tercero puede testear/deploy siguiendo docs.

#### Aprobación

- [ ] Autorizada para ejecutar  
- [ ] Completada y revisada → ✅ + fecha

> **No iniciar Fase 7 sin:** `Autorizo Fase 7`

---

## 7. Checklist de avance

```text
[x] Fase 0  Bootstrap Foundry          → ✅ 2026-08-26
[x] Fase 1  Diseño + TDD               → ✅ 2026-08-26
[ ] Fase 2  Core O(1) + unit           → requiere: Autorizo Fase 2
[ ] Fase 3  Lockup + notify            → requiere: Autorizo Fase 3
[ ] Fase 4  Fuzz / invariant / gas     → requiere: Autorizo Fase 4
[ ] Fase 5  Deploy + ABI               → requiere: Autorizo Fase 5
[ ] Fase 6  Frontend (opcional)        → requiere: Autorizo Fase 6 | Omitir
[ ] Fase 7  Docs finales               → requiere: Autorizo Fase 7
```

---

## 8. Definition of Done (global)

1. `pragma solidity 0.8.24` fijo.
2. Rewards O(1); sin iterar usuarios.
3. `updateReward` en `stake` / `withdraw` / `getReward`.
4. Scaling factor documentado; precisión verificada en tests con warp.
5. CEI + SafeERC20; custom errors.
6. Lockup dinámico y periodos de reward con `RewardPeriodActive` donde corresponda.
7. Suite: unit + fuzz + invariant (+ ataque reentrancy).
8. Invariante de vault respetada.
9. Diagramas y plan actualizados al cerrar.
10. Frontend solo si la Fase 6 fue autorizada.

---

## 9. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Precisión / dust en división | Scaling `1e18`/`1e36`; fuzz + asserts de acotación |
| `notifyRewardAmount` mal calibrado | Tests mid-period; leftover explícito |
| Lockup griefing UX | Eventos + views `unlockTime`; docs claras |
| Reentrancy en claim/withdraw | CEI + ReentrancyGuard + test malicioso |
| Token fee-on-transfer | Fuera de alcance v1 o medir delta (decidir en Fase 1) |
| Avance sin review | **Protocolo de autorización por fase** |

---

## 10. Próximo paso inmediato

**Estado actual:** Fases **0–1** cerradas (bootstrap + interfaz/TDD rojo).  
**Siguiente acción:** autorizar **Fase 2** (core O(1): `updateReward`, stake/withdraw/getReward, poner lifecycle en verde).

Responde: **`Autorizo Fase 2`** para continuar.
