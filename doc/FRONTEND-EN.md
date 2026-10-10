# Frontend demo — Phase 6

Next.js UI (App Router) for the `StakingRewards` pool: connect wallet, stake, claim, withdraw/exit and view `earned` + lockup.

## Prerequisites

1. Node **≥ 20** (22 recommended via nvm).
2. Anvil + deploy (see [`DEPLOY-EN.md`](./DEPLOY-EN.md)).
3. ABIs in `frontend/abi/` (`./script/export-abi.sh`).

## Setup

```bash
cd frontend
cp .env.example .env.local
# Edit addresses using the Deploy.s.sol log

npm install
npm run dev
```

Open http://localhost:3000. In MetaMask:

- Network: Localhost 8545, chainId **31337**
- Import the Anvil #0 private key (local demo only)

## Happy path

1. **Connect wallet** → Anvil account on chain 31337.
2. **Stake** `1` (or more) → if needed, the app approves the token and then calls `stake`.
3. Wait a few seconds (or `Refrescar`) → **Earned** increases if there is an active period (`notify` at deploy).
4. **Claim reward** → `getReward()` sends rewards to your wallet (the full accrued amount).
5. With lockup: **Withdraw/Exit** disabled until `unlockTime`; claim is still allowed.
6. Without lockup (or expired): partial **Withdraw** or **Exit** (full unstake + claim).

## Scripts

| Command | Usage |
|---------|-----|
| `npm run dev` | Dev server |
| `npm run build` | Production build |
| `npm test` | Vitest + RTL |
| `npm run lint` | ESLint |

## Next.js / env note

On the client, Next **only** injects variables accessed statically:

```ts
process.env.NEXT_PUBLIC_RPC_URL  // ✅
process.env["NEXT_PUBLIC_RPC_URL"] // ❌ usually ends up undefined in the browser
```

That is why `src/lib/env.ts` reads each key explicitly.
