import { formatUnits, parseUnits } from "ethers";

/**
 * Formatea un amount on-chain (bigint) a string legible.
 * @param {bigint} value
 * @param {number} [decimals=18]
 * @param {number} [maxFrac=4]
 */
export function formatToken(value: bigint, decimals = 18, maxFrac = 4): string {
  const full = formatUnits(value, decimals);
  const [i, f = ""] = full.split(".");
  if (maxFrac <= 0 || !f) return i;
  const trimmed = f.slice(0, maxFrac).replace(/0+$/, "");
  return trimmed ? `${i}.${trimmed}` : i;
}

/**
 * Parsea input de UI a wei/bigint.
 * @param {string} input
 * @param {number} [decimals=18]
 * @returns {bigint}
 * @throws {Error} Si el input no es un decimal válido positivo.
 */
export function parseTokenInput(input: string, decimals = 18): bigint {
  const trimmed = input.trim();
  if (!trimmed || !/^\d+(\.\d+)?$/.test(trimmed)) {
    throw new Error("Cantidad inválida");
  }
  const value = parseUnits(trimmed, decimals);
  if (value <= 0n) throw new Error("Cantidad debe ser > 0");
  return value;
}

/**
 * Acorta address `0x1234…abcd`.
 * @param {string} address
 * @param {number} [chars=4]
 */
export function shortAddress(address: string, chars = 4): string {
  if (address.length < 10) return address;
  return `${address.slice(0, 2 + chars)}…${address.slice(-chars)}`;
}

/**
 * Timestamp unix → fecha local corta.
 * @param {bigint | number} ts
 */
export function formatUnlock(ts: bigint | number): string {
  const n = typeof ts === "bigint" ? Number(ts) : ts;
  if (!n) return "—";
  return new Date(n * 1000).toLocaleString();
}
