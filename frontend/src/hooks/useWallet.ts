"use client";

import { useCallback, useEffect, useState } from "react";
import type { BrowserProvider, Signer } from "ethers";
import { getBrowserProvider } from "@/lib/contracts";
import type { PublicEnv } from "@/lib/env";

export type WalletState = {
  address: string | null;
  chainId: number | null;
  connecting: boolean;
  error: string | null;
};

/**
 * Conexión básica a wallet inyectada + chequeo de chain.
 * @param {PublicEnv | null} env
 */
export function useWallet(env: PublicEnv | null) {
  const [state, setState] = useState<WalletState>({
    address: null,
    chainId: null,
    connecting: false,
    error: null,
  });
  const [provider, setProvider] = useState<BrowserProvider | null>(null);
  const [signer, setSigner] = useState<Signer | null>(null);

  const refresh = useCallback(async (bp: BrowserProvider) => {
    const network = await bp.getNetwork();
    const s = await bp.getSigner();
    const address = await s.getAddress();
    setProvider(bp);
    setSigner(s);
    setState({
      address,
      chainId: Number(network.chainId),
      connecting: false,
      error: null,
    });
  }, []);

  const connect = useCallback(async () => {
    if (!env) {
      setState((s) => ({ ...s, error: "Configura NEXT_PUBLIC_* en .env.local" }));
      return;
    }
    setState((s) => ({ ...s, connecting: true, error: null }));
    try {
      const bp = getBrowserProvider();
      await bp.send("eth_requestAccounts", []);
      const network = await bp.getNetwork();
      if (Number(network.chainId) !== env.NEXT_PUBLIC_CHAIN_ID) {
        try {
          await window.ethereum?.request({
            method: "wallet_switchEthereumChain",
            params: [{ chainId: `0x${env.NEXT_PUBLIC_CHAIN_ID.toString(16)}` }],
          });
        } catch {
          throw new Error(
            `Cambia la red a chainId ${env.NEXT_PUBLIC_CHAIN_ID} (Anvil = 31337)`,
          );
        }
      }
      await refresh(bp);
    } catch (err) {
      setState((s) => ({
        ...s,
        connecting: false,
        error: err instanceof Error ? err.message : String(err),
      }));
    }
  }, [env, refresh]);

  const disconnect = useCallback(() => {
    setProvider(null);
    setSigner(null);
    setState({ address: null, chainId: null, connecting: false, error: null });
  }, []);

  useEffect(() => {
    if (!window.ethereum?.on) return;
    const onAccounts = (accounts: unknown) => {
      const list = accounts as string[];
      if (!list?.length) disconnect();
      else if (provider) void refresh(provider);
    };
    const onChain = () => {
      if (provider) void refresh(provider);
    };
    window.ethereum.on("accountsChanged", onAccounts);
    window.ethereum.on("chainChanged", onChain);
    return () => {
      window.ethereum?.removeListener?.("accountsChanged", onAccounts);
      window.ethereum?.removeListener?.("chainChanged", onChain);
    };
  }, [provider, refresh, disconnect]);

  const wrongChain =
    state.chainId != null && env != null && state.chainId !== env.NEXT_PUBLIC_CHAIN_ID;

  return { ...state, provider, signer, connect, disconnect, wrongChain };
}
