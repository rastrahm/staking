import { z } from "zod";

/**
 * Esquema de variables públicas del frontend (Fase 6).
 * Fallan en parse con mensaje claro si falta alguna address/RPC.
 */
const addressSchema = z
  .string()
  .regex(/^0x[a-fA-F0-9]{40}$/, "Debe ser address 0x + 40 hex");

const publicEnvSchema = z.object({
  NEXT_PUBLIC_RPC_URL: z.string().url(),
  NEXT_PUBLIC_CHAIN_ID: z.coerce.number().int().positive(),
  NEXT_PUBLIC_STAKING_ADDRESS: addressSchema,
  NEXT_PUBLIC_STAKE_TOKEN: addressSchema,
  NEXT_PUBLIC_REWARD_TOKEN: addressSchema,
});

/** Config tipada leída de `process.env` (solo `NEXT_PUBLIC_*`). */
export type PublicEnv = z.infer<typeof publicEnvSchema>;

/**
 * Next solo inyecta `NEXT_PUBLIC_*` con acceso estático
 * (`process.env.NEXT_PUBLIC_FOO`), no vía `process.env` dinámico.
 */
function readBundledPublicEnv(): Record<string, string | undefined> {
  return {
    NEXT_PUBLIC_RPC_URL: process.env.NEXT_PUBLIC_RPC_URL,
    NEXT_PUBLIC_CHAIN_ID: process.env.NEXT_PUBLIC_CHAIN_ID,
    NEXT_PUBLIC_STAKING_ADDRESS: process.env.NEXT_PUBLIC_STAKING_ADDRESS,
    NEXT_PUBLIC_STAKE_TOKEN: process.env.NEXT_PUBLIC_STAKE_TOKEN,
    NEXT_PUBLIC_REWARD_TOKEN: process.env.NEXT_PUBLIC_REWARD_TOKEN,
  };
}

/**
 * Parsea el env público. Útil en tests y en bootstrap del cliente.
 * @param {Record<string, string | undefined>} [raw] Override (tests); default = bundled Next env
 * @returns {PublicEnv}
 */
export function parsePublicEnv(
  raw: Record<string, string | undefined> = readBundledPublicEnv(),
): PublicEnv {
  return publicEnvSchema.parse(raw);
}

/**
 * Intenta parsear sin lanzar; devuelve `{ success, data|error }`.
 * @param {Record<string, string | undefined>} [raw]
 */
export function safeParsePublicEnv(
  raw: Record<string, string | undefined> = readBundledPublicEnv(),
) {
  return publicEnvSchema.safeParse(raw);
}
