# Handoff — Module 03 StakingRewards

Guide for a third party picking up the repo: what is there, how to verify it, and what is out of scope for v1.

**Module status:** Phases **0–7** ✅ (2026-08-27).

---

## 1. What it is

Synthetix-style staking pool:

- Proportional rewards in **O(1)** (`rewardPerTokenStored` + `updateReward`).
- Solidity **`0.8.24`**, Foundry, OpenZeppelin **v5.2** (`Ownable2Step`, `ReentrancyGuardTransient`, `SafeERC20`).
- Optional lockup; claim allowed during lockup; withdraw/exit not.
- Next.js demo UI in `frontend/` (Phase 6).

---

## 2. Up and running in 5 minutes

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge build && forge test

# Local demo
anvil   # another terminal
forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
./script/export-abi.sh

cd frontend && cp .env.example .env.local   # addresses from the log
npm install && npm run dev                 # http://localhost:3000
```

Details: [`DEPLOY-EN.md`](./DEPLOY-EN.md) · [`FRONTEND-EN.md`](./FRONTEND-EN.md).

---

## 3. Docs map

| Doc | Purpose |
|-----|----------|
| [`INDEX-EN.md`](./INDEX-EN.md) | Index |
| [`00-plan-implementacion-EN.md`](./00-plan-implementacion-EN.md) | Phases and DoD |
| [`04-modelo-matematico-EN.md`](./04-modelo-matematico-EN.md) | Formulas + invariant |
| [`05-decisiones-logica-gas-EN.md`](./05-decisiones-logica-gas-EN.md) | Decisions, logic, gas margin |
| [`01-diagrama-clases-EN.md`](./01-diagrama-clases-EN.md) · [`02`](./02-diagrama-flujo-EN.md) · [`03`](./03-flujograma-EN.md) | Classes / sequences / flowcharts |
| [`GAS-EN.md`](./GAS-EN.md) | Gas baseline |
| [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) · [`ATAQUES-EN.md`](./ATAQUES-EN.md) | Security |
| This file | Handoff + limits + backlog |

---

## 4. v1 decisions (frozen)

- `PRECISION = 1e18`
- Same token stake/reward **allowed**
- No `Pausable` / no surplus `rescue`
- `exit()` yes; **all-or-nothing** claim (no partial claim)
- Only “honest” ERC-20s (no fee-on-transfer / rebase)
- `notify`: tokens **already** in the vault; the fn only sets rate/period
- Each `stake` resets `unlockTime`
- Times/durations packed into `uint64` (one slot)

---

## 5. Known limitations

| Topic | Impact |
|------|---------|
| No pause / rescue | Surplus or donated tokens may get stuck |
| Trusted owner | `notify` / durations are admin power |
| Timestamps | SWC-116 accepted (Synthetix style) |
| Truncation dust | Users may “lose” wei of dust; no typical overpayment |
| Full claim | There is no partial `getReward(amount)` |
| Demo frontend | Anvil/MetaMask; not a complete prod wallet UX |
| Cancun | `ReentrancyGuardTransient` requires a network with EIP-1153 |

---

## 6. Backlog improvements (not v1)

1. Partial reward claim.
2. `Pausable` + `rescueERC20` (surplus only, never accounted stake).
3. Timelock / multisig as owner in prod.
4. Measured fee-on-transfer support (balance delta) if the product requires it.
5. UI: robust automatic network switching, indexing, tx history.
6. `PRECISION = 1e36` if extreme rates require it (would break current math compat).

---

## 7. Verification checklist (third party)

- [ ] `forge test` green (unit + fuzz + invariant + attack).
- [ ] Anvil deploy + `cast call` `rewardRate` / `periodFinish` > 0 after notify.
- [ ] Stake → warp/wait → `earned` increases → `getReward` credits the wallet.
- [ ] With lockup > 0: withdraw reverts; claim OK.
- [ ] `frontend`: `npm test` + `npm run build`; connect/stake flow on Anvil.

---

## 8. Design contact

Canonical model and invariant: [`04-modelo-matematico-EN.md`](./04-modelo-matematico-EN.md).  
If the code diverges, **update the docs in the same PR** (do not leave the handoff out of date).
