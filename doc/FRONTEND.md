# Frontend demo — Fase 6

UI Next.js (App Router) para el pool `StakingRewards`: conectar wallet, stake, claim, withdraw/exit y ver `earned` + lockup.

## Prerrequisitos

1. Node **≥ 20** (recomendado 22 via nvm).
2. Anvil + deploy (ver [`DEPLOY.md`](./DEPLOY.md)).
3. ABIs en `frontend/abi/` (`./script/export-abi.sh`).

## Setup

```bash
cd frontend
cp .env.example .env.local
# Edita addresses con el log del Deploy.s.sol

npm install
npm run dev
```

Abre http://localhost:3000. En MetaMask:

- Red: Localhost 8545, chainId **31337**
- Importa la private key Anvil #0 (solo demo local)

## Flujo feliz

1. **Conectar wallet** → cuenta Anvil en chain 31337.
2. **Stake** `1` (o más) → si hace falta, la app aprueba el token y luego `stake`.
3. Espera unos segundos (o `Refrescar`) → **Earned** sube si hay periodo activo (`notify` en deploy).
4. **Claim reward** → `getReward()` manda rewards a tu wallet (todo el acumulado).
5. Si hay lockup: **Withdraw/Exit** deshabilitados hasta `unlockTime`; claim sí permitido.
6. Sin lockup (o vencido): **Withdraw** parcial o **Exit** (unstake total + claim).

## Scripts

| Comando | Uso |
|---------|-----|
| `npm run dev` | Dev server |
| `npm run build` | Build producción |
| `npm test` | Vitest + RTL |
| `npm run lint` | ESLint |

## Nota Next.js / env

En el cliente, Next **solo** inyecta variables con acceso estático:

```ts
process.env.NEXT_PUBLIC_RPC_URL  // ✅
process.env["NEXT_PUBLIC_RPC_URL"] // ❌ suele quedar undefined en browser
```

Por eso `src/lib/env.ts` lee cada clave de forma explícita.
