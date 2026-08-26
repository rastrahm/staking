# 03 — Staking & Reward Distribution

Protocolo de staking con distribución proporcional de rewards en O(1) (estilo Synthetix), usando Foundry y Solidity `0.8.24`.

**Estado:** Fases 0–5 ✅. Siguiente: Fase 6 (UI, opcional) o Fase 7 (docs).

---

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24`, OpenZeppelin v5.2 |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Modelo | Accumulator `rewardPerTokenStored` (O(1)) |

---

## Documentación

| Documento | Contenido |
|-----------|-----------|
| [`doc/INDEX.md`](doc/INDEX.md) | Índice |
| [`doc/00-plan-implementacion.md`](doc/00-plan-implementacion.md) | Plan por fases (requiere autorización) |
| [`doc/DEPLOY.md`](doc/DEPLOY.md) | Deploy Anvil / testnet + ABI |
| [`doc/01-diagrama-clases.md`](doc/01-diagrama-clases.md) | Diagrama de clases |
| [`doc/02-diagrama-flujo.md`](doc/02-diagrama-flujo.md) | Secuencias |
| [`doc/03-flujograma.md`](doc/03-flujograma.md) | Flujogramas de decisión |
| [`doc/04-modelo-matematico.md`](doc/04-modelo-matematico.md) | Fórmulas e invariante |
| [`doc/GAS.md`](doc/GAS.md) | Baseline de gas |
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
```

Playbook completo: [`doc/DEPLOY.md`](doc/DEPLOY.md).

---

## Estructura

```text
src/           # StakingRewards + interfaces + mocks
test/          # unit / fuzz / invariant / attack
script/        # Deploy + export-abi
lib/           # forge-std + openzeppelin-contracts
doc/           # Plan, diagramas, auditoría, ABI
frontend/abi/  # ABI exportados (UI Fase 6)
```
