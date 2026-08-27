# Handoff — Módulo 03 StakingRewards

Guía para un tercero que retoma el repo: qué hay, cómo verificarlo y qué queda fuera de v1.

**Estado del módulo:** Fases **0–7** ✅ (2026-08-27).

---

## 1. Qué es

Pool de staking estilo Synthetix:

- Rewards proporcionales en **O(1)** (`rewardPerTokenStored` + `updateReward`).
- Solidity **`0.8.24`**, Foundry, OpenZeppelin **v5.2** (`Ownable2Step`, `ReentrancyGuardTransient`, `SafeERC20`).
- Lockup opcional; claim permitido durante lockup; withdraw/exit no.
- Demo UI Next.js en `frontend/` (Fase 6).

---

## 2. Arranque en 5 minutos

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge build && forge test

# Demo local
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
./script/export-abi.sh

cd frontend && cp .env.example .env.local   # addresses del log
npm install && npm run dev                 # http://localhost:3000
```

Detalle: [`DEPLOY.md`](./DEPLOY.md) · [`FRONTEND.md`](./FRONTEND.md).

---

## 3. Mapa de docs

| Doc | Para qué |
|-----|----------|
| [`INDEX.md`](./INDEX.md) | Índice |
| [`00-plan-implementacion.md`](./00-plan-implementacion.md) | Fases y DoD |
| [`04-modelo-matematico.md`](./04-modelo-matematico.md) | Fórmulas + invariante |
| [`01-diagrama-clases.md`](./01-diagrama-clases.md) · [`02`](./02-diagrama-flujo.md) · [`03`](./03-flujograma.md) | Clases / secuencias / flujogramas |
| [`GAS.md`](./GAS.md) | Baseline gas |
| [`SWC-AUDIT.md`](./SWC-AUDIT.md) · [`ATAQUES.md`](./ATAQUES.md) | Seguridad |
| Este archivo | Handoff + límites + backlog |

---

## 4. Decisiones v1 (congeladas)

- `PRECISION = 1e18`
- Same token stake/reward **permitido**
- Sin `Pausable` / sin `rescue` de surplus
- `exit()` sí; claim **all-or-nothing** (no claim parcial)
- Solo ERC-20 “honestos” (no fee-on-transfer / rebase)
- `notify`: tokens **ya** en el vault; la fn solo rate/periodo
- Cada `stake` reinicia `unlockTime`
- Tiempos/durations empaquetados en `uint64` (un slot)

---

## 5. Limitaciones conocidas

| Tema | Impacto |
|------|---------|
| Sin pause / rescue | Surplus o tokens donados pueden quedar atrapados |
| Owner confiable | `notify` / durations son poder admin |
| Timestamps | SWC-116 aceptado (estilo Synthetix) |
| Dust por truncamiento | Usuarios pueden “perder” wei de dust; no sobrepago típico |
| Claim total | No hay `getReward(amount)` parcial |
| Frontend demo | Anvil/MetaMask; no prod wallet UX completa |
| Cancun | `ReentrancyGuardTransient` requiere red con EIP-1153 |

---

## 6. Mejoras backlog (no v1)

1. Claim parcial de rewards.
2. `Pausable` + `rescueERC20` (solo surplus, nunca stake contabilizado).
3. Timelock / multisig como owner en prod.
4. Soporte medido a fee-on-transfer (delta balance) si el producto lo exige.
5. UI: switch de red automático robusto, índices, historial de txs.
6. `PRECISION = 1e36` si rates extremos lo requieren (rompería compat math actual).

---

## 7. Checklist de verificación (tercero)

- [ ] `forge test` verde (unit + fuzz + invariant + attack).
- [ ] Deploy Anvil + `cast call` `rewardRate` / `periodFinish` > 0 tras notify.
- [ ] Stake → warp/espera → `earned` sube → `getReward` acredita wallet.
- [ ] Con lockup > 0: withdraw revierte; claim OK.
- [ ] `frontend`: `npm test` + `npm run build`; flujo conectar/stake en Anvil.

---

## 8. Contacto de diseño

Modelo e invariante canónicos: [`04-modelo-matematico.md`](./04-modelo-matematico.md).  
Si el código diverge, **actualizar docs en el mismo PR** (no dejar handoff desfasado).
