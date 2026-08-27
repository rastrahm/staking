/**
 * Extrae mensaje usable de errores ethers / custom errors del pool.
 * @param {unknown} err
 * @returns {string}
 */
export function humanizeError(err: unknown): string {
  if (err == null) return "Error desconocido";
  if (typeof err === "string") return err;

  const e = err as {
    shortMessage?: string;
    reason?: string;
    message?: string;
    code?: string;
    data?: string;
    info?: { error?: { message?: string } };
  };

  const raw =
    e.shortMessage ||
    e.reason ||
    e.info?.error?.message ||
    e.message ||
    String(err);

  const custom: Record<string, string> = {
    ZeroAmount: "Cantidad cero no permitida",
    InsufficientStake: "Stake insuficiente",
    LockupActive: "Lockup activo: aún no puedes withdraw/exit",
    RewardPeriodActive: "Periodo de rewards activo",
    RewardRateTooHigh: "Reward rate demasiado alto vs balance del vault",
    ZeroAddress: "Address cero",
    TransferFailed: "Transfer falló",
    "user rejected": "Transacción rechazada en la wallet",
    ACTION_REJECTED: "Transacción rechazada en la wallet",
  };

  for (const [key, msg] of Object.entries(custom)) {
    if (raw.includes(key)) return msg;
  }

  return raw.length > 180 ? `${raw.slice(0, 177)}…` : raw;
}
