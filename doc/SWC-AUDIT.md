# Auditoría SWC — StakingRewards

Verificación de `StakingRewards` contra el [SWC Registry](https://swcregistry.io/) (EIP-1470) y principios del monorepo (CEI, ReentrancyGuard, O(1), custom errors, SafeERC20).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS) y [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Contrato auditado:** `src/StakingRewards.sol` (+ `src/interfaces/IStakingRewards.sol`)  
**Fecha:** 2026-08-26  
**Referencia tests:** `test/StakingRewards.t.sol`, `test/unit/`, `test/fuzz/`, `test/invariant/`, `test/attack/`  
**Modelo:** [`04-modelo-matematico.md`](./04-modelo-matematico.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 33 |
| ⚠️ Informativo (diseño / estándar / trust) | 3 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance del pool Synthetix-style. Riesgos informativos: dependencia de `block.timestamp`, race de `approve` ERC-20 externo, y confianza en owner + tokens honestos (sin fee-on-transfer / rebase).

**Principios del suite verificados:**

| Principio | Estado |
|-----------|--------|
| CEI antes de transfers | ✅ `stake` / `withdraw` / `getReward` / `exit` |
| `ReentrancyGuard` | ✅ + tests callback ERC-20 |
| Sin loops sobre usuarios | ✅ O(1) accumulator |
| SafeERC20 | ✅ |
| Custom errors (no `require` strings) | ✅ |
| Pragma fijo `0.8.24` | ✅ |
| Ownable2Step | ✅ admin `notify` / durations |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en `StakingRewards` |
|----|--------|--------|--------|-------------------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en todas las funciones |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; checks `amount > 0`, `balance >= amount` |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | `SafeERC20.safeTransfer` / `safeTransferFrom` |
| SWC-105 | Unprotected Ether Withdrawal | No | N/A | Sin ETH / `payable` / `.call{value}` |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Sí | ✅ | CEI + `nonReentrant`; `test/attack/ReentrancyAttack.t.sol` |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | Tokens/`_balances`/`_totalSupply` private; getters explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` |
| SWC-113 | DoS with Failed Call | Parcial | ✅ | Fallo de transfer → revert tx completa (estado intacto) |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Race de `approve` del ERC-20 de stake (externo) |
| SWC-115 | Authorization through tx.origin | No | N/A | No se usa `tx.origin`; `onlyOwner` OZ |
| SWC-116 | Block values as a proxy for time | Sí | ⚠️ | `block.timestamp` para rate/lockup (uso Synthetix aceptado) |
| SWC-117 | Signature Malleability | No | N/A | Sin firmas / `ecrecover` / permit |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing con OZ `Ownable2Step` / `ReentrancyGuard` |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG |
| SWC-121 | Missing Protection against Signature Replay | No | N/A | Sin firmas |
| SWC-122 | Lack of Proper Signature Verification | No | N/A | Sin verificación de firmas |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + unit/fuzz/invariant |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | Sin assembly de storage |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `IStakingRewards, Ownable2Step, ReentrancyGuard` |
| SWC-126 | Insufficient Gas Griefing | No | N/A | Sin relayers con stipend fijo |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Sí | ✅ | Paths O(1); sin loops sobre stakers |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge build` / tests |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin dead code material (`TransferFailed` en interfaz reservado) |
| SWC-132 | Unexpected Ether balance | No | N/A | Contrato no maneja ETH |
| SWC-133 | Hash Collisions (var-length args) | No | N/A | Sin hashing multi-dinámico propio |
| SWC-134 | Message call with hardcoded gas | No | N/A | Sin `{gas: …}` |
| SWC-135 | Code With No Effects | No | N/A | Sin no-ops relevantes |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Balances/earned públicos por diseño DeFi |

---

## Riesgos informativos

### SWC-114 — Front-running de `approve` (ERC-20 de stake)

El pool no gestiona allowances. El usuario debe `approve(staking, amount)` en el **stakingToken** antes de `stake`. Ese `approve` hereda el race clásico ERC-20.

**Mitigación de producto:** `approve(0)` → nuevo amount, o token con `permit` / `increaseAllowance`.

### SWC-116 — `block.timestamp` como reloj

`lastTimeRewardApplicable`, `periodFinish`, `unlockTime` y `notifyRewardAmount` dependen de `block.timestamp`. Mineros/validadores pueden sesgar segundos, no reescribir periodos largos de forma económica.

**Estado:** ⚠️ By design (Synthetix y casi todo staking on-chain). Aceptado en v1.

### Owner trust + tokens no estándar

| Tema | Riesgo | Tratamiento v1 |
|------|--------|----------------|
| `notifyRewardAmount` / durations | Owner malicioso puede manipular rate/duration (no roba stake ajeno vía withdraw ajeno) | Trust en owner; Ownable2Step |
| `setLockupDuration` alto | Griefing a **nuevos** stakes (reinicia unlock); unlocks existentes intactos | Documentado; claim sigue OK en lockup |
| Fee-on-transfer / rebase | Contabilidad incorrecta | **Fuera de alcance** — solo ERC-20 honestos |
| Same token stake==reward | Solvencia de notify descuenta `totalSupply` | Cubierto + test |
| Pool vacío (`totalSupply == 0`) | Emisión no avanza el acumulador (rewards quedan en vault / dust) | Comportamiento Synthetix clásico |
| Sin `rescue` / Pausable | Tokens donados de más pueden quedar atrapados; sin pause global | Aceptado v1 (menos superficie) |

---

## Checklist principios monorepo (09-security / suite)

| Principio | ¿Cumple? | Notas |
|-----------|----------|--------|
| Checks-Effects-Interactions | ✅ | Effects de balances/rewards antes de `safeTransfer*` |
| Pull over Push | ✅ | Usuario llama `getReward` / `withdraw` (no push automático) |
| ReentrancyGuard | ✅ | + CEI; ataque callback documentado |
| Access control admin | ✅ | `onlyOwner` en notify/set* |
| Custom errors | ✅ | `ZeroAmount`, `InsufficientStake`, `LockupActive`, … |
| O(1) gas / sin loops de usuarios | ✅ | Accumulator `rewardPerTokenStored` |
| SafeERC20 | ✅ | |
| Invariantes de solvencia | ✅ | `invariant_StakeTokenExact`, `invariant_RewardSolvency` |

---

## Mapeo SWC → tests

| SWC | Test(s) |
|-----|---------|
| SWC-101 | fuzz stake/withdraw; unit insufficient / zero |
| SWC-104 / 113 | `test_stake_revertsWhenTransferFromFails` |
| SWC-107 | `test_getReward_reentrancyReverts_noDrain`, `test_withdraw_reentrancyReverts_noDrain` |
| SWC-114 | Documental (approve externo); sin superficie permit en pool |
| SWC-116 | phase3 lockup/`vm.warp`; notify mid-period |
| SWC-123 | unit + fuzz + invariant |
| SWC-128 | diseño O(1); invariant multi-actor sin loops on-chain |

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- Campañas: [`ATAQUES.md`](./ATAQUES.md)
- Modelo: [`04-modelo-matematico.md`](./04-modelo-matematico.md)
- Gas: [`GAS.md`](./GAS.md)
