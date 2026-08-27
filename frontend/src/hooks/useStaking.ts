"use client";

import { useCallback, useEffect, useState } from "react";
import type { Signer } from "ethers";
import { MaxUint256 } from "ethers";
import {
  createReadContracts,
  createWriteContracts,
} from "@/lib/contracts";
import type { PublicEnv } from "@/lib/env";
import { humanizeError } from "@/lib/errors";
import { parseTokenInput } from "@/lib/format";

export type PoolSnapshot = {
  staked: bigint;
  earned: bigint;
  walletStake: bigint;
  allowance: bigint;
  unlockTime: bigint;
  lockupDuration: bigint;
  totalSupply: bigint;
  periodFinish: bigint;
  stakeSymbol: string;
  rewardSymbol: string;
  decimals: number;
};

const emptySnap = (): PoolSnapshot => ({
  staked: 0n,
  earned: 0n,
  walletStake: 0n,
  allowance: 0n,
  unlockTime: 0n,
  lockupDuration: 0n,
  totalSupply: 0n,
  periodFinish: 0n,
  stakeSymbol: "TOKEN",
  rewardSymbol: "RWD",
  decimals: 18,
});

/**
 * Lectura + acciones del pool (approve/stake/withdraw/getReward/exit).
 * @param {PublicEnv | null} env
 * @param {string | null} address
 * @param {Signer | null} signer
 */
export function useStaking(
  env: PublicEnv | null,
  address: string | null,
  signer: Signer | null,
) {
  const [snap, setSnap] = useState<PoolSnapshot>(emptySnap);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!env) return;
    try {
      const { staking, stakeToken, rewardToken } = createReadContracts(env);
      const [decimals, stakeSymbol, rewardSymbol, totalSupply, periodFinish, lockupDuration] =
        await Promise.all([
          stakeToken.decimals() as Promise<number>,
          stakeToken.symbol() as Promise<string>,
          rewardToken.symbol() as Promise<string>,
          staking.totalSupply() as Promise<bigint>,
          staking.periodFinish() as Promise<bigint>,
          staking.lockupDuration() as Promise<bigint>,
        ]);

      let staked = 0n;
      let earned = 0n;
      let walletStake = 0n;
      let allowance = 0n;
      let unlockTime = 0n;

      if (address) {
        [staked, earned, walletStake, allowance, unlockTime] = await Promise.all([
          staking.balanceOf(address) as Promise<bigint>,
          staking.earned(address) as Promise<bigint>,
          stakeToken.balanceOf(address) as Promise<bigint>,
          stakeToken.allowance(address, env.NEXT_PUBLIC_STAKING_ADDRESS) as Promise<bigint>,
          staking.unlockTime(address) as Promise<bigint>,
        ]);
      }

      setSnap({
        staked,
        earned,
        walletStake,
        allowance,
        unlockTime,
        lockupDuration,
        totalSupply,
        periodFinish,
        stakeSymbol,
        rewardSymbol,
        decimals: Number(decimals),
      });
      setError(null);
    } catch (err) {
      setError(humanizeError(err));
    }
  }, [env, address]);

  useEffect(() => {
    void refresh();
    const id = setInterval(() => void refresh(), 12_000);
    return () => clearInterval(id);
  }, [refresh]);

  const run = useCallback(
    async (label: string, fn: () => Promise<{ hash: string }>) => {
      setBusy(label);
      setError(null);
      setTxHash(null);
      try {
        const tx = await fn();
        setTxHash(tx.hash);
        await refresh();
      } catch (err) {
        setError(humanizeError(err));
      } finally {
        setBusy(null);
      }
    },
    [refresh],
  );

  const approve = useCallback(
    async (amountInput?: string) => {
      if (!env || !signer) return;
      const { stakeToken } = createWriteContracts(env, signer);
      const amount = amountInput
        ? parseTokenInput(amountInput, snap.decimals)
        : MaxUint256;
      await run("approve", async () => {
        const tx = await stakeToken.approve(env.NEXT_PUBLIC_STAKING_ADDRESS, amount);
        await tx.wait();
        return tx;
      });
    },
    [env, signer, snap.decimals, run],
  );

  const stake = useCallback(
    async (amountInput: string) => {
      if (!env || !signer) return;
      const amount = parseTokenInput(amountInput, snap.decimals);
      const { staking, stakeToken } = createWriteContracts(env, signer);
      await run("stake", async () => {
        const allowance = (await stakeToken.allowance(
          await signer.getAddress(),
          env.NEXT_PUBLIC_STAKING_ADDRESS,
        )) as bigint;
        if (allowance < amount) {
          const txA = await stakeToken.approve(env.NEXT_PUBLIC_STAKING_ADDRESS, amount);
          await txA.wait();
        }
        const tx = await staking.stake(amount);
        await tx.wait();
        return tx;
      });
    },
    [env, signer, snap.decimals, run],
  );

  const withdraw = useCallback(
    async (amountInput: string) => {
      if (!env || !signer) return;
      const amount = parseTokenInput(amountInput, snap.decimals);
      const { staking } = createWriteContracts(env, signer);
      await run("withdraw", async () => {
        const tx = await staking.withdraw(amount);
        await tx.wait();
        return tx;
      });
    },
    [env, signer, snap.decimals, run],
  );

  const getReward = useCallback(async () => {
    if (!env || !signer) return;
    const { staking } = createWriteContracts(env, signer);
    await run("getReward", async () => {
      const tx = await staking.getReward();
      await tx.wait();
      return tx;
    });
  }, [env, signer, run]);

  const exit = useCallback(async () => {
    if (!env || !signer) return;
    const { staking } = createWriteContracts(env, signer);
    await run("exit", async () => {
      const tx = await staking.exit();
      await tx.wait();
      return tx;
    });
  }, [env, signer, run]);

  const lockupActive =
    snap.unlockTime > 0n &&
    BigInt(Math.floor(Date.now() / 1000)) < snap.unlockTime;

  return {
    snap,
    busy,
    error,
    txHash,
    refresh,
    approve,
    stake,
    withdraw,
    getReward,
    exit,
    lockupActive,
  };
}
