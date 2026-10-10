# 03 — Staking & Reward Distribution

Staking protocol with proportional reward distribution in **O(1)** (Synthetix-style). Solidity `0.8.24` + Foundry + Next.js demo.

**Status:** Phases **0–7** ✅ (module closed for handoff).

---

## Stack

| Layer | Technology |
|------|------------|
| Contracts | Solidity `0.8.24`, OpenZeppelin v5.2 (`Ownable2Step`, `ReentrancyGuardTransient`, `SafeERC20`) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Model | Accumulator `rewardPerTokenStored` |
| Demo UI | Next.js 15, ethers v6, Zod, Vitest |

---

## Documentation

| Document | Contents |
|-----------|-----------|
| [`doc/HANDOFF-EN.md`](doc/HANDOFF-EN.md) | **Start here** — limits, backlog, third-party checklist |
| [`doc/INDEX-EN.md`](doc/INDEX-EN.md) | Full index |
| [`doc/00-plan-implementacion-EN.md`](doc/00-plan-implementacion-EN.md) | Phased plan + DoD |
| [`doc/04-modelo-matematico-EN.md`](doc/04-modelo-matematico-EN.md) | Formulas and invariant |
| [`doc/05-decisiones-logica-gas-EN.md`](doc/05-decisiones-logica-gas-EN.md) | Decisions, logic and gas margin |
| [`doc/DEPLOY-EN.md`](doc/DEPLOY-EN.md) | Anvil / testnet deploy + ABI |
| [`doc/FRONTEND-EN.md`](doc/FRONTEND-EN.md) | Demo UI |
| [`doc/01-diagrama-clases-EN.md`](doc/01-diagrama-clases-EN.md) | Classes |
| [`doc/02-diagrama-flujo-EN.md`](doc/02-diagrama-flujo-EN.md) | Sequences |
| [`doc/03-flujograma-EN.md`](doc/03-flujograma-EN.md) | Flowcharts |
| [`doc/GAS-EN.md`](doc/GAS-EN.md) | Gas |
| [`doc/SWC-AUDIT-EN.md`](doc/SWC-AUDIT-EN.md) | SWC audit |
| [`doc/ATAQUES-EN.md`](doc/ATAQUES-EN.md) | Attack campaigns |
| [`portfolio/`](portfolio/) | Portfolio page (ES/EN) |

---

## Quick start

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test

# Local demo
anvil   # another terminal
forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast

./script/export-abi.sh

cd frontend && cp .env.example .env.local && npm install && npm run dev
```

Playbooks: [`doc/DEPLOY-EN.md`](doc/DEPLOY-EN.md) · [`doc/FRONTEND-EN.md`](doc/FRONTEND-EN.md) · [`doc/HANDOFF-EN.md`](doc/HANDOFF-EN.md).

---

## Structure

```text
src/           # StakingRewards + interfaces + mocks
test/          # unit / fuzz / invariant / attack
script/        # Deploy + export-abi
lib/           # forge-std + openzeppelin-contracts
doc/           # Plan, diagrams, audit, handoff, ABI
frontend/      # Next.js demo (ABIs in frontend/abi/)
```

---

## Definition of Done (summary)

See the full checklist in the plan §8. In short: O(1) + CEI + SafeERC20 + custom errors + lockup/notify + Foundry suite + aligned docs + demo frontend.
