# 03 — Staking & Reward Distribution

Protocolo de staking con distribución proporcional de rewards en O(1) (estilo Synthetix), usando Foundry y Solidity `0.8.24`.

**Estado:** Fases 0–2 ✅. Siguiente: Fase 3 (requiere autorización).

---

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24`, OpenZeppelin v5.0.2 |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Modelo | Accumulator `rewardPerTokenStored` (O(1)) |

---

## Documentación

| Documento | Contenido |
|-----------|-----------|
| [`doc/INDEX.md`](doc/INDEX.md) | Índice |
| [`doc/00-plan-implementacion.md`](doc/00-plan-implementacion.md) | Plan por fases (requiere autorización) |
| [`doc/01-diagrama-clases.md`](doc/01-diagrama-clases.md) | Diagrama de clases |
| [`doc/02-diagrama-flujo.md`](doc/02-diagrama-flujo.md) | Secuencias |
| [`doc/04-modelo-matematico.md`](doc/04-modelo-matematico.md) | Fórmulas e invariante |

---

## Uso rápido

```bash
# Usar el forge de Foundry (no el paquete npm homónimo)
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

---

## Estructura

```text
src/           # Contratos (placeholder StakingRewards)
test/          # Tests Foundry
script/        # Deploy scripts
lib/           # forge-std + openzeppelin-contracts
doc/           # Plan y diagramas
```
