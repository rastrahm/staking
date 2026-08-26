# Campañas de ataque — StakingRewards

> **Protocolo:** tests Foundry defensivos (`vm.expectRevert` / invariantes). El “éxito” del ataque es que **falle** o quede documentado como limitación.  
> **Fuera de alcance:** scripts de exploit ofensivos o procedimientos para drenar fondos ajenos.

Contrato: `src/StakingRewards.sol`  
Auditoría: [`SWC-AUDIT.md`](./SWC-AUDIT.md)

---

## Resumen

| Campaña | Nombre | SWC / tema | Estado |
|---------|--------|------------|--------|
| A | Integridad stake / withdraw / claim | SWC-101, 123 | ✅ |
| B | Reentrancy (callback ERC-20) | SWC-107 | ✅ |
| C | Orden de txs / approve externo | SWC-114 | ✅ Documental |
| D | Tiempo / lockup / notify | SWC-116 | ✅ |
| E | Solvencia / fuzz / invariant | SWC-123, 128 | ✅ |

---

## Campaña A — Integridad de balances

**Hipótesis:** nadie retira más stake del suyo; zero amount revierte; transfer fallida no deja estado a medias.

| # | Escenario | Resultado esperado | Test |
|---|-----------|--------------------|------|
| A1 | `stake(0)` | `ZeroAmount` | `test_stake_revertsZeroAmount` |
| A2 | `withdraw` > balance | `InsufficientStake` | `test_withdraw_revertsZeroAmountAndInsufficientStake` |
| A3 | `withdraw(0)` | `ZeroAmount` | idem |
| A4 | `transferFrom` del stake revierte | tx revierte; sin crédito | `test_stake_revertsWhenTransferFromFails` |
| A5 | Claim limpia `earned` | reward transferido; earned 0 | `test_getReward_transfersAndClearsEarned` |
| A6 | `exit` saca stake + reward | balances 0 | `test_exit_withdrawsStakeAndPaysReward` |
| A7 | Non-owner `notify` | revert Ownable | `test_notify_revertsZeroAndNonOwnerAndRateTooHigh` |

---

## Campaña B — Reentrancy

**Hipótesis:** un ERC-20 con callback en `transfer` no puede double-claim ni double-withdraw.

| # | Escenario | Resultado esperado | Test |
|---|-----------|--------------------|------|
| B1 | Reenter `getReward` en payout | `ReentrancyGuardReentrantCall`; vault intacto | `test_getReward_reentrancyReverts_noDrain` |
| B2 | Reenter `withdraw` en unstake | idem; stake intacto | `test_withdraw_reentrancyReverts_noDrain` |

Mitigación: CEI (effects antes de transfer) + `nonReentrant`.

---

## Campaña C — Orden de transacciones (SWC-114)

**Hipótesis:** el pool no elimina el race de `approve` del stakingToken.

| # | Escenario | Clasificación | Acción |
|---|-----------|---------------|--------|
| C1 | `approve` N→M sin pasar por 0 | Limitación ERC-20 | Documental (ver SWC-AUDIT) |

Mitigación off-chain: `approve(0)` luego amount; o permit en el token.

---

## Campaña D — Tiempo, lockup y funding

**Hipótesis:** lockup bloquea unstake hasta `unlockTime`; notify mid-period no borra earned; duration no cambia con periodo activo.

| # | Escenario | Resultado esperado | Test |
|---|-----------|--------------------|------|
| D1 | Withdraw antes de unlock | `LockupActive` | `test_withdraw_revertsWhileLockupActive` |
| D2 | Withdraw en `unlockTime` exacto | OK | `test_withdraw_okAtExactUnlockTime` |
| D3 | `getReward` durante lockup | OK | `test_getReward_allowedDuringLockup` |
| D4 | Notify mid-period | earned previo intacto | `test_notifyMidPeriod_preservesAlreadyEarned` |
| D5 | `setRewardsDuration` con periodo vivo | `RewardPeriodActive` | phase3 + core |
| D6 | Restake extiende unlock | `unlockTime` nuevo | `test_restake_extendsUnlockTime` |

---

## Campaña E — Solvencia bajo fuzz / invariant

**Hipótesis:** el vault no promete más rewards de los que tiene; stake token cuadra con `totalSupply`.

| # | Escenario | Resultado esperado | Test |
|---|-----------|--------------------|------|
| E1 | Fuzz stake/withdraw | balances coherentes | `testFuzz_stakeWithdraw_*` |
| E2 | Fuzz 2 stakers | prorrateo acotado | `testFuzz_twoStakers_proportional` |
| E3 | Notify underfunded | `RewardRateTooHigh` | `testFuzz_notify_revertsIfUnderfunded` |
| E4 | Invariant stake | `balance == totalSupply` | `invariant_StakeTokenExact` |
| E5 | Invariant rewards | `balance >= Σ earned` | `invariant_RewardSolvency` |

---

## Fuera de alcance (v1)

- Fee-on-transfer / rebase tokens  
- Permit en el pool  
- Pausable / rescue de surplus  
- Exploits ofensivos / PoC de drenado real  

Ver [`SWC-AUDIT.md`](./SWC-AUDIT.md) sección informativos.
