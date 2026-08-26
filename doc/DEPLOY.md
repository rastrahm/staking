# Deploy playbook — StakingRewards (Fase 5)

Comandos para desplegar mocks + pool, notificar rewards iniciales y exportar ABIs.

## Prerrequisitos

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cp .env.example .env   # no commitear .env real
```

## 1. Anvil (demo local)

Terminal A:

```bash
anvil
```

- RPC: `http://127.0.0.1:8545`
- Chain id: `31337`
- Cuenta #0:
  - Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
  - Private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

Terminal B — deploy con broadcast:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

Copia las addresses del log (`Stake token`, `Reward token`, `StakingRewards`).

Variables útiles (opcionales):

| Env | Default | Uso |
|-----|---------|-----|
| `DEPLOY_MOCKS` | `true` | Si `false`, usa `STAKE_TOKEN` + `REWARD_TOKEN` |
| `SAME_TOKEN` | `false` | Un solo mock para stake y reward |
| `REWARDS_DURATION` | `604800` (7d) | Segundos del periodo |
| `LOCKUP_DURATION` | `0` | Lockup de nuevos stakes |
| `MINT_AMOUNT` | `1e24` | Mint a broadcaster |
| `INITIAL_REWARD_POT` | `1e23` | Transfer + `notifyRewardAmount` (0 = skip) |
| `INITIAL_OWNER` | broadcaster | Owner del pool |

Ejemplo same-token:

```bash
SAME_TOKEN=true forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

## 2. Exportar ABIs

```bash
chmod +x script/export-abi.sh
./script/export-abi.sh
```

Genera (en `doc/abi/` y `frontend/abi/`):

- `StakingRewards.json`
- `IStakingRewards.json`
- `MockERC20.json`

## 3. Frontend env (Fase 6, si se autoriza)

```bash
NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545
NEXT_PUBLIC_CHAIN_ID=31337
NEXT_PUBLIC_STAKING_ADDRESS=0x...
NEXT_PUBLIC_STAKE_TOKEN=0x...
NEXT_PUBLIC_REWARD_TOKEN=0x...
```

## 4. Testnet (opcional)

```bash
source .env
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --verify   # requiere ETHERSCAN_API_KEY
```

Documenta addresses resultantes fuera de git (o en un `.env.local` ignorado).

## Ownership

`notifyRewardAmount`, `setRewardsDuration` y `setLockupDuration` son `onlyOwner`.  
En producción: multisig / Timelock como `INITIAL_OWNER`, no una EOA frágil.

## Verificación rápida post-deploy

```bash
cast call $STAKING "totalSupply()(uint256)" --rpc-url http://127.0.0.1:8545
cast call $STAKING "rewardRate()(uint256)" --rpc-url http://127.0.0.1:8545
cast call $STAKING "periodFinish()(uint256)" --rpc-url http://127.0.0.1:8545
```
