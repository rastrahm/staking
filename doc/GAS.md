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

## Antes vs después (suite unit/lifecycle/phase3)

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

### Post-opt detalle

| Función | Min | Avg | Median | Max |
|---------|-----|-----|--------|-----|
| `stake` | 35 951 | 120 432 | 129 650 | 129 662 |
| `withdraw` | 36 337 | 64 112 | 38 816 | 129 722 |
| `getReward` | 115 882 | 115 882 | 115 882 | 115 882 |
| `exit` | 38 509 | 91 439 | 91 439 | 144 370 |
| `notifyRewardAmount` | 23 819 | 60 050 | 63 204 | 66 432 |

---

## Tradeoffs aceptados

| Decisión | Por qué |
|----------|---------|
| Cancun + transient | Alineado a `02-crypto-bank` |
| `uint64` tiempos/durations | Suficiente on-chain; overflow → revert |
| Deploy un poco más caro | Preferimos runtime de usuarios más barato |
| SafeERC20 / Ownable2Step | Seguridad > gas residual |

---

## Seguridad

`test/attack/ReentrancyAttack.t.sol` verde con transient: reentrada → `ReentrancyGuardReentrantCall`, sin drenado. Suite completa: **35 tests**.
