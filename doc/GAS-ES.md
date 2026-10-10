# Optimización de gas — StakingRewards

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract 'StakingRewardsCoreTest|StakingRewardsLifecycleTest|StakingRewardsPhase3Test' --gas-report
```

---

## Cambios aplicados (2026-08-26)

| Optimización | Tradeoff | Efecto |
|--------------|----------|--------|
| `ReentrancyGuardTransient` (EIP-1153) | Cancun + OZ **v5.2.0** | Guard más barato en cada mutator |
| Packing `uint64` ×4 (finish / lastUpdate / durations) | Caps `type(uint64).max` | Menos SLOAD/SSTORE en notify/stake |
| Cache `rewardPerToken` en `updateReward` + `_earned` | Ninguno | Evita doble cálculo del acumulador |
| Cache `account = msg.sender` | Ninguno | Menos `CALLER` |
| `unchecked` tras checks de resta | Checks deben permanecer | Menos overflow checks |
| OZ `v5.0.2` → `v5.2.0` | Pin alineado a módulo 02 | Habilita transient |

---

## Yul en hot paths (2026-09-16)

| Optimización | Tradeoff | Efecto |
|--------------|----------|--------|
| `lastTimeRewardApplicable` en assembly (`min(ts, finish)`) | Menos legible | Menos JUMP/comparaciones Solidity |
| `rewardPerToken`: 1× `SLOAD` packed + `mul/div` Yul | Overflow mul igual que `unchecked` previo | Menos SLOAD + aritmética más directa |
| `_earned` en Yul (`mul/div/add`) | Guard `rpt < paid` → return pending | Menos overhead en cada materialización |

**Semántica:** misma fórmula O(1); suite **35/35** verde (unit/fuzz/invariant/attack).

### Post-opt (packing/transient) → post-Yul

| Métrica | Post-opt | Post-Yul | Δ |
|---------|----------|----------|---|
| Deployment Cost | 1 199 350 | 1 184 009 | **−15 341** |
| Deployment Size | 5872 | 5801 | **−71** bytes |
| `stake` avg | 120 432 | 120 157 | **−275** |
| `withdraw` avg | 64 112 | 63 704 | **−408** |
| `getReward` avg | 115 882 | 115 526 | **−356** |
| `exit` avg | 91 439 | 91 049 | **−390** |
| `notifyRewardAmount` avg | 60 050 | 60 033 | **−17** |
| `earned` avg | 15 325 | 14 947 | **−378** |

**Lectura:** el ahorro es **marginal** (como se anticipaba), pero consistente en views/mutators que tocan el acumulador. El deploy también bajó un poco (bytecode más compacto en el math).

### Post-Yul detalle

| Función | Min | Avg | Median | Max |
|---------|-----|-----|--------|-----|
| `stake` | 35 690 | 120 157 | 129 389 | 129 401 |
| `withdraw` | 35 912 | 63 704 | 38 391 | 129 357 |
| `getReward` | 115 526 | 115 526 | 115 526 | 115 526 |
| `exit` | 38 084 | 91 049 | 91 049 | 144 014 |
| `notifyRewardAmount` | 23 819 | 60 033 | 63 203 | 66 330 |

---

## Antes vs después (suite unit/lifecycle/phase3) — fase packing/transient

| Métrica | Antes | Después | Δ |
|---------|-------|---------|---|
| Deployment Cost | 1 166 857 | 1 199 350 | **+32 493** (OZ 5.2 + getters explícitos) |
| Deployment Size | 5424 | 5872 | +448 bytes |
| `stake` avg | 127 790 | 120 432 | **−7 358** |
| `withdraw` avg | 73 311 | 64 112 | **−9 199** |
| `getReward` avg | 121 987 | 115 882 | **−6 105** |
| `exit` avg | 100 053 | 91 439 | **−8 614** |
| `notifyRewardAmount` avg | 92 169 | 60 050 | **−32 119** |

**Lectura:** el deploy sube un poco (dependencia + ABI de getters); las rutas calientes de usuario/admin **bajan** de forma clara, sobre todo `notify` y `withdraw`.

---

## Tradeoffs aceptados

| Decisión | Por qué |
|----------|---------|
| Cancun + transient | Alineado a `02-crypto-bank` |
| `uint64` tiempos/durations | Suficiente on-chain; overflow → revert |
| Deploy un poco más caro (fase OZ 5.2) | Preferimos runtime de usuarios más barato |
| SafeERC20 / Ownable2Step | Seguridad > gas residual |
| Yul en math | Ahorro fino; CEI/SafeERC20 intactos; auditar con más cuidado |

---

## Seguridad

`test/attack/ReentrancyAttack.t.sol` verde con transient: reentrada → `ReentrancyGuardReentrantCall`, sin drenado. Suite completa: **35 tests**.
