import { BrowserProvider, Contract, JsonRpcProvider, type Signer } from "ethers";
import stakingAbiJson from "../../abi/StakingRewards.json";
import erc20AbiJson from "../../abi/MockERC20.json";
import type { PublicEnv } from "./env";

/** ABI del pool (Foundry artifact → campo `abi`). */
export const stakingAbi = stakingAbiJson.abi;
/** ABI ERC-20 (Mock / token real con approve/balanceOf). */
export const erc20Abi = erc20AbiJson.abi;

/**
 * Provider de solo lectura hacia el RPC configurado.
 * @param {string} rpcUrl
 */
export function createReadProvider(rpcUrl: string): JsonRpcProvider {
  return new JsonRpcProvider(rpcUrl);
}

/**
 * Contratos de lectura (sin signer).
 * @param {PublicEnv} env
 * @param {JsonRpcProvider} [provider]
 */
export function createReadContracts(env: PublicEnv, provider?: JsonRpcProvider) {
  const p = provider ?? createReadProvider(env.NEXT_PUBLIC_RPC_URL);
  return {
    provider: p,
    staking: new Contract(env.NEXT_PUBLIC_STAKING_ADDRESS, stakingAbi, p),
    stakeToken: new Contract(env.NEXT_PUBLIC_STAKE_TOKEN, erc20Abi, p),
    rewardToken: new Contract(env.NEXT_PUBLIC_REWARD_TOKEN, erc20Abi, p),
  };
}

/**
 * Contratos conectados a un signer (wallet).
 * @param {PublicEnv} env
 * @param {Signer} signer
 */
export function createWriteContracts(env: PublicEnv, signer: Signer) {
  return {
    staking: new Contract(env.NEXT_PUBLIC_STAKING_ADDRESS, stakingAbi, signer),
    stakeToken: new Contract(env.NEXT_PUBLIC_STAKE_TOKEN, erc20Abi, signer),
    rewardToken: new Contract(env.NEXT_PUBLIC_REWARD_TOKEN, erc20Abi, signer),
  };
}

/**
 * Obtiene BrowserProvider desde `window.ethereum` (MetaMask / inyectado).
 * @throws {Error} Si no hay wallet inyectada.
 */
export function getBrowserProvider(): BrowserProvider {
  const eth = typeof window !== "undefined" ? window.ethereum : undefined;
  if (!eth) {
    throw new Error("No hay wallet inyectada (instala MetaMask u otra).");
  }
  return new BrowserProvider(eth);
}

declare global {
  interface Window {
    ethereum?: {
      request: (args: { method: string; params?: unknown[] }) => Promise<unknown>;
      on?: (event: string, handler: (...args: unknown[]) => void) => void;
      removeListener?: (event: string, handler: (...args: unknown[]) => void) => void;
    };
  }
}
