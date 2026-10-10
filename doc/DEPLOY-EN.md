# Deploy playbook — StakingRewards (Phase 5)

Commands to deploy mocks + pool, notify initial rewards and export ABIs.

## Prerequisites

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cp .env.example .env   # do not commit the real .env
```

## 1. Anvil (local demo)

Terminal A:

```bash
anvil
```

- RPC: `http://127.0.0.1:8545`
- Chain id: `31337`
- Account #0:
  - Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
  - Private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

Terminal B — deploy with broadcast:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

Copy the addresses from the log (`Stake token`, `Reward token`, `StakingRewards`).

Useful variables (optional):

| Env | Default | Usage |
|-----|---------|-----|
| `DEPLOY_MOCKS` | `true` | If `false`, uses `STAKE_TOKEN` + `REWARD_TOKEN` |
| `SAME_TOKEN` | `false` | A single mock for stake and reward |
| `REWARDS_DURATION` | `604800` (7d) | Period length in seconds |
| `LOCKUP_DURATION` | `0` | Lockup for new stakes |
| `MINT_AMOUNT` | `1e24` | Mint to broadcaster |
| `INITIAL_REWARD_POT` | `1e23` | Transfer + `notifyRewardAmount` (0 = skip) |
| `INITIAL_OWNER` | broadcaster | Pool owner |

Same-token example:

```bash
SAME_TOKEN=true forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

## 2. Export ABIs

```bash
chmod +x script/export-abi.sh
./script/export-abi.sh
```

Generates (in `doc/abi/` and `frontend/abi/`):

- `StakingRewards.json`
- `IStakingRewards.json`
- `MockERC20.json`

## 3. Frontend env (Phase 6)

See the full playbook: [`FRONTEND-EN.md`](./FRONTEND-EN.md).

```bash
cd frontend
cp .env.example .env.local
# Fill in addresses from the Deploy log

NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545
NEXT_PUBLIC_CHAIN_ID=31337
NEXT_PUBLIC_STAKING_ADDRESS=0x...
NEXT_PUBLIC_STAKE_TOKEN=0x...
NEXT_PUBLIC_REWARD_TOKEN=0x...

npm install && npm run dev
```

## 4. Testnet (optional)

```bash
source .env
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --verify   # requires ETHERSCAN_API_KEY
```

Record the resulting addresses outside git (or in an ignored `.env.local`).

## Ownership

`notifyRewardAmount`, `setRewardsDuration` and `setLockupDuration` are `onlyOwner`.  
In production: multisig / Timelock as `INITIAL_OWNER`, not a fragile EOA.

## Quick post-deploy verification

```bash
cast call $STAKING "totalSupply()(uint256)" --rpc-url http://127.0.0.1:8545
cast call $STAKING "rewardRate()(uint256)" --rpc-url http://127.0.0.1:8545
cast call $STAKING "periodFinish()(uint256)" --rpc-url http://127.0.0.1:8545
```
