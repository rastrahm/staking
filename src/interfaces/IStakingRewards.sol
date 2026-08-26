// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IStakingRewards
 * @notice Pool de staking con distribución proporcional de rewards en O(1) (estilo Synthetix).
 * @dev Stake = depósito del token de stake para participar del prorrateo del saco de rewards.
 *      Reward = recompensa cobrable; no aumenta el stake salvo que el usuario la vuelva a depositar.
 *
 * ## Fórmulas (PRECISION = 1e18)
 *
 * ```
 * lastTimeRewardApplicable = min(block.timestamp, periodFinish)
 *
 * rewardPerToken =
 *   totalSupply == 0
 *     ? rewardPerTokenStored
 *     : rewardPerTokenStored
 *         + (lastTimeRewardApplicable - lastUpdateTime) * rewardRate * PRECISION / totalSupply
 *
 * earned(account) =
 *   rewards[account]
 *     + balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account]) / PRECISION
 * ```
 *
 * ## Invariante de vault
 *
 * Con tokens distintos o el mismo token:
 * - `totalStaked` := `totalSupply()` (suma de balances en stake).
 * - `unassignedRewards` := balance del `rewardsToken` en el contrato menos la suma de rewards
 *   ya liquidados en `rewards[user]` pendientes de claim y menos el residual del periodo
 *   aún no materializado en el acumulador (dust de truncamiento incluido).
 * - Forma operativa (tests / invariant suite):
 *   `rewardsToken.balanceOf(vault) >= Σ earned(user)` (solvencia; dust puede hacer `>`).
 *   `stakingToken.balanceOf(vault) >= totalSupply` (si stake ≠ reward; si son el mismo token,
 *   `balance >= totalStaked + pendingRewardsAccounting`).
 *
 * ## Decisiones v1 (Fase 1)
 *
 * - `PRECISION = 1e18`.
 * - `stakingToken == rewardsToken` permitido.
 * - Sin `Pausable` en v1.
 * - `exit()` incluido (withdraw + getReward).
 * - Solo ERC-20 “honestos” (sin fee-on-transfer / rebase).
 * - `notifyRewardAmount`: el caller debe haber transferido antes los rewards al contrato;
 *   la función solo actualiza contabilidad y exige solvencia del rate.
 */
interface IStakingRewards {
    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitido al depositar stake.
    /// @param user Cuenta que hizo stake.
    /// @param amount Cantidad de stakingToken depositada.
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitido al retirar stake.
    /// @param user Cuenta que retiró.
    /// @param amount Cantidad de stakingToken retirada.
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice Emitido al cobrar rewards.
    /// @param user Cuenta que cobró.
    /// @param reward Cantidad de rewardsToken transferida.
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Emitido al fondear / re-fondear el periodo de rewards.
    /// @param reward Cantidad nueva anunciada para el periodo (wei del rewardsToken).
    event RewardAdded(uint256 reward);

    /// @notice Emitido al cambiar la duración del periodo de rewards.
    /// @param newDuration Nueva duración en segundos.
    event RewardsDurationUpdated(uint256 newDuration);

    /// @notice Emitido al cambiar la duración de lockup de nuevos stakes.
    /// @param newDuration Nueva duración en segundos.
    event LockupDurationUpdated(uint256 newDuration);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Monto cero donde se exige amount > 0.
    error ZeroAmount();

    /// @notice Hay un periodo de rewards activo; no se puede cambiar `rewardsDuration`.
    error RewardPeriodActive();

    /// @notice Stake insuficiente para el withdraw solicitado.
    error InsufficientStake();

    /// @notice Transferencia ERC-20 fallida (uso defensivo; SafeERC20 suele revertir antes).
    error TransferFailed();

    /// @notice Lockup aún no venció para `msg.sender`.
    error LockupActive();

    /// @notice Address cero donde se exige un token / owner válido.
    error ZeroAddress();

    /// @notice El contrato no tiene balance de rewards suficiente para el `rewardRate` propuesto.
    error RewardRateTooHigh();

    // -------------------------------------------------------------------------
    // Views — tokens y contabilidad de stake
    // -------------------------------------------------------------------------

    /// @notice Token que los usuarios depositan (stake).
    /// @return Token ERC-20 de stake.
    function stakingToken() external view returns (IERC20);

    /// @notice Token con el que se pagan las recompensas.
    /// @return Token ERC-20 de reward.
    function rewardsToken() external view returns (IERC20);

    /// @notice Total de stakingToken en stake en el pool.
    /// @return Suma de todos los balances en stake (`totalStaked`).
    function totalSupply() external view returns (uint256);

    /// @notice Balance en stake de una cuenta.
    /// @param account Cuenta a consultar.
    /// @return Cantidad de stakingToken en stake.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Timestamp hasta el cual aplica el `rewardRate` actual (cap del periodo).
    /// @return `min(block.timestamp, periodFinish)`.
    function lastTimeRewardApplicable() external view returns (uint256);

    /// @notice Acumulador global de reward por unidad de stake (escalado por PRECISION).
    /// @return rewardPerToken actual (lazy).
    function rewardPerToken() external view returns (uint256);

    /// @notice Rewards cobrables de una cuenta (liquidados + proyectados).
    /// @param account Cuenta a consultar.
    /// @return Cantidad de rewardsToken pendiente de claim.
    function earned(address account) external view returns (uint256);

    /// @notice Rewards por segundo del periodo actual.
    /// @return Rate en wei de rewardsToken / segundo.
    function rewardRate() external view returns (uint256);

    /// @notice Timestamp en el que termina el periodo de emisión actual.
    /// @return `periodFinish`.
    function periodFinish() external view returns (uint256);

    /// @notice Duración configurada de cada periodo de rewards (segundos).
    /// @return `rewardsDuration`.
    function rewardsDuration() external view returns (uint256);

    /// @notice Duración de lockup aplicada a nuevos stakes (segundos).
    /// @return `lockupDuration`.
    function lockupDuration() external view returns (uint256);

    /// @notice Timestamp desde el cual `account` puede hacer withdraw.
    /// @param account Cuenta a consultar.
    /// @return `unlockTime[account]`.
    function unlockTime(address account) external view returns (uint256);

    /// @notice Último valor materializado del acumulador global.
    /// @return `rewardPerTokenStored`.
    function rewardPerTokenStored() external view returns (uint256);

    /// @notice Checkpoint del acumulador ya cobrado/liquidado por cuenta.
    /// @param account Cuenta a consultar.
    /// @return `userRewardPerTokenPaid[account]`.
    function userRewardPerTokenPaid(address account) external view returns (uint256);

    /// @notice Rewards ya liquidados pendientes de transferir (post-`updateReward`).
    /// @param account Cuenta a consultar.
    /// @return `rewards[account]`.
    function rewards(address account) external view returns (uint256);

    // -------------------------------------------------------------------------
    // User actions
    // -------------------------------------------------------------------------

    /// @notice Deposita `amount` de stakingToken en stake.
    /// @dev Requiere approve previo. Aplica `updateReward(msg.sender)`. Extiende lockup.
    /// @param amount Cantidad a depositar; debe ser > 0.
    function stake(uint256 amount) external;

    /// @notice Retira `amount` de stakingToken del stake.
    /// @dev Aplica `updateReward`. Respeta lockup. CEI + SafeERC20.
    /// @param amount Cantidad a retirar; debe ser > 0 y ≤ balance.
    function withdraw(uint256 amount) external;

    /// @notice Cobra los rewards pendientes de `msg.sender`.
    /// @dev Aplica `updateReward`. CEI + SafeERC20.
    function getReward() external;

    /// @notice Retira todo el stake de `msg.sender` y cobra rewards.
    /// @dev Equivale a `withdraw(balanceOf(msg.sender))` + `getReward()` (respetando lockup).
    function exit() external;

    // -------------------------------------------------------------------------
    // Admin / distributor
    // -------------------------------------------------------------------------

    /// @notice Anuncia `reward` tokens para el periodo (`rewardsDuration`).
    /// @dev Solo owner. Los tokens deben estar ya en el contrato. `updateReward(address(0))`.
    /// @param reward Cantidad nueva de rewardsToken a distribuir en el periodo.
    function notifyRewardAmount(uint256 reward) external;

    /// @notice Cambia la duración del periodo de rewards.
    /// @dev Solo owner. Requiere periodo inactivo (`block.timestamp > periodFinish`).
    /// @param duration Nueva duración en segundos; debe ser > 0.
    function setRewardsDuration(uint256 duration) external;

    /// @notice Cambia la duración de lockup para stakes futuros / política de extensión.
    /// @dev Solo owner.
    /// @param duration Nueva duración en segundos (0 = sin lockup).
    function setLockupDuration(uint256 duration) external;
}
