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
| [`doc/HANDOFF.md`](doc/HANDOFF.md) | **Empezar aquí** — límites, backlog, checklist tercero |
| [`doc/INDEX.md`](doc/INDEX.md) | Índice completo |
| [`doc/00-plan-implementacion.md`](doc/00-plan-implementacion.md) | Plan por fases + DoD |
| [`doc/04-modelo-matematico.md`](doc/04-modelo-matematico.md) | Fórmulas e invariante |
| [`doc/DEPLOY.md`](doc/DEPLOY.md) | Deploy Anvil / testnet + ABI |
| [`doc/FRONTEND.md`](doc/FRONTEND.md) | Demo UI |
| [`doc/01-diagrama-clases.md`](doc/01-diagrama-clases.md) | Clases |
| [`doc/02-diagrama-flujo.md`](doc/02-diagrama-flujo.md) | Secuencias |
| [`doc/03-flujograma.md`](doc/03-flujograma.md) | Flujogramas |
| [`doc/GAS.md`](doc/GAS.md) | Gas |
| [`doc/SWC-AUDIT.md`](doc/SWC-AUDIT.md) | Auditoría SWC |
| [`doc/ATAQUES.md`](doc/ATAQUES.md) | Campañas de ataque |

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

Playbooks: [`doc/DEPLOY.md`](doc/DEPLOY.md) · [`doc/FRONTEND.md`](doc/FRONTEND.md) · [`doc/HANDOFF.md`](doc/HANDOFF.md).

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
