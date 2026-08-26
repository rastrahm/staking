# Optimización de gas — StakingRewards (Fase 4 baseline)

Baseline medido tras Fases 0–3 (sin micro-opts agresivas). Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract 'StakingRewardsCoreTest|StakingRewardsLifecycleTest|StakingRewardsPhase3Test' --gas-report
```

> `gas-report.txt` está en `.gitignore` si se redirige a disco.

---

## Baseline (2026-08-26)

| Función | Min | Avg | Median | Max |
|---------|-----|-----|--------|-----|
| Deployment `StakingRewards` | — | **1 146 921** | — | size 5424 |
| `stake` | 42 944 | 127 790 | 136 622 | 136 634 |
| `withdraw` | 46 599 | 73 311 | 49 056 | 136 298 |
| `getReward` | 121 987 | 121 987 | 121 987 | 121 987 |
| `exit` | 48 752 | 100 053 | 100 053 | 151 355 |
| `notifyRewardAmount` | 23 819 | 92 169 | 104 071 | 104 380 |
| `setRewardsDuration` | 25 860 | 27 878 | 25 865 | 31 910 |
| `setLockupDuration` | 23 679 | 33 415 | 29 734 | 46 834 |
| `earned` (view) | 18 339 | 18 371 | 18 339 | 18 435 |

Valores tomados del `--gas-report` de la suite unit/lifecycle/phase3.

---

## Tradeoffs aceptados (v1)

| Decisión | Por qué | Coste |
|----------|---------|--------|
| `ReentrancyGuard` (storage, no transient) | Compatible y claro; Cancun transient queda como mejora opcional | Guard más caro que EIP-1153 |
| `SafeERC20` | Tokens no estándar / return data | Extra gas vs `transfer` crudo |
| `Ownable2Step` | Ownership más seguro | 2 txs para transferir owner |
| `PRECISION = 1e18` | Suficiente; dust residual acotado | Menos margen que `1e36` en edge extrema |
| Lockup en cada stake | UX predecible; reinicia reloj | SSTORE `unlockTime` por stake |
| Sin `Pausable` | Menos superficie admin (Fase 1) | Sin kill-switch on-chain |

---

## Posibles opts futuras (no aplicadas)

- `ReentrancyGuardTransient` (Cancun) — alinear con módulo 02.
- Packing de `periodFinish` / `lastUpdateTime` / `rewardRate` si el layout lo permite.
- `unchecked` en restas de balance tras checks `>=`.
- Cachear `msg.sender` en paths multi-SLOAD.

---

## Seguridad vs gas (Fase 4)

Los tests de reentrancy confirman que `nonReentrant` hace revertir toda la tx en callback ERC-20 malicioso (`getReward` / `withdraw`). El coste del guard se acepta frente a drenado.
