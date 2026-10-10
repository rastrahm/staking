# 03 — Staking & Reward Distribution

Protocolo de staking con distribución proporcional de rewards en **O(1)** (estilo Synthetix). Solidity `0.8.24` + Foundry + demo Next.js.

**Estado:** Fases **0–7** ✅ (módulo cerrado para handoff).

---

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24`, OpenZeppelin v5.2 (`Ownable2Step`, `ReentrancyGuardTransient`, `SafeERC20`) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Modelo | Accumulator `rewardPerTokenStored` |
| UI demo | Next.js 15, ethers v6, Zod, Vitest |

---

## Documentación

| Documento | Contenido |
|-----------|-----------|
| [`doc/HANDOFF-ES.md`](doc/HANDOFF-ES.md) | **Empezar aquí** — límites, backlog, checklist tercero |
| [`doc/INDEX-ES.md`](doc/INDEX-ES.md) | Índice completo |
| [`doc/00-plan-implementacion-ES.md`](doc/00-plan-implementacion-ES.md) | Plan por fases + DoD |
| [`doc/04-modelo-matematico-ES.md`](doc/04-modelo-matematico-ES.md) | Fórmulas e invariante |
| [`doc/05-decisiones-logica-gas-ES.md`](doc/05-decisiones-logica-gas-ES.md) | Decisiones, lógica y margen de gas |
| [`doc/DEPLOY-ES.md`](doc/DEPLOY-ES.md) | Deploy Anvil / testnet + ABI |
| [`doc/FRONTEND-ES.md`](doc/FRONTEND-ES.md) | Demo UI |
| [`doc/01-diagrama-clases-ES.md`](doc/01-diagrama-clases-ES.md) | Clases |
| [`doc/02-diagrama-flujo-ES.md`](doc/02-diagrama-flujo-ES.md) | Secuencias |
| [`doc/03-flujograma-ES.md`](doc/03-flujograma-ES.md) | Flujogramas |
| [`doc/GAS-ES.md`](doc/GAS-ES.md) | Gas |
| [`doc/SWC-AUDIT-ES.md`](doc/SWC-AUDIT-ES.md) | Auditoría SWC |
| [`doc/ATAQUES-ES.md`](doc/ATAQUES-ES.md) | Campañas de ataque |
| [`portfolio/`](portfolio/) | Página portafolio (ES/EN) |

---

## Uso rápido

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test

# Demo local
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast

./script/export-abi.sh

cd frontend && cp .env.example .env.local && npm install && npm run dev
```

Playbooks: [`doc/DEPLOY-ES.md`](doc/DEPLOY-ES.md) · [`doc/FRONTEND-ES.md`](doc/FRONTEND-ES.md) · [`doc/HANDOFF-ES.md`](doc/HANDOFF-ES.md).

---

## Estructura

```text
src/           # StakingRewards + interfaces + mocks
test/          # unit / fuzz / invariant / attack
script/        # Deploy + export-abi
lib/           # forge-std + openzeppelin-contracts
doc/           # Plan, diagramas, auditoría, handoff, ABI
frontend/      # Demo Next.js (ABIs en frontend/abi/)
```

---

## Definition of Done (resumen)

Ver checklist completo en el plan §8. En corto: O(1) + CEI + SafeERC20 + custom errors + lockup/notify + suite Foundry + docs alineados + frontend demo.
