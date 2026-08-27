"use client";

import { useMemo, useState } from "react";
import { safeParsePublicEnv, type PublicEnv } from "@/lib/env";
import { useWallet } from "@/hooks/useWallet";
import { useStaking } from "@/hooks/useStaking";
import { formatToken, formatUnlock, shortAddress } from "@/lib/format";

/**
 * Demo UI: conectar wallet, stake / claim / withdraw con UX de lockup.
 */
export function StakingApp() {
  const envResult = useMemo(() => safeParsePublicEnv(), []);
  const env: PublicEnv | null = envResult.success ? envResult.data : null;

  const wallet = useWallet(env);
  const staking = useStaking(env, wallet.address, wallet.signer);
  const [amount, setAmount] = useState("1");

  if (!envResult.success || !env) {
    return (
      <section className="panel" role="alert">
        <h2 className="panel-title">Falta configuración</h2>
        <p className="muted">
          Copia <code>.env.example</code> → <code>.env.local</code> con las
          addresses del deploy Anvil (ver <code>doc/DEPLOY.md</code>).
        </p>
        <pre className="error-box">
          {envResult.success ? "Env incompleto" : envResult.error.message}
        </pre>
      </section>
    );
  }

  const { snap } = staking;
  const dec = snap.decimals;

  return (
    <div className="app-grid">
      <header className="hero">
        <p className="brand">StakingRewards</p>
        <h1 className="headline">Pool O(1)</h1>
        <p className="lede">
          Stake, acumula rewards y retira cuando el lockup lo permita.
        </p>
        <div className="cta-row">
          {!wallet.address ? (
            <button
              type="button"
              className="btn btn-primary"
              onClick={() => void wallet.connect()}
              disabled={wallet.connecting}
            >
              {wallet.connecting ? "Conectando…" : "Conectar wallet"}
            </button>
          ) : (
            <>
              <span className="pill" data-testid="wallet-address">
                {shortAddress(wallet.address)}
              </span>
              <button type="button" className="btn btn-ghost" onClick={wallet.disconnect}>
                Desconectar
              </button>
            </>
          )}
        </div>
        {(wallet.error || wallet.wrongChain) && (
          <p className="warn" role="status">
            {wallet.wrongChain
              ? `Red incorrecta (esperada ${env.NEXT_PUBLIC_CHAIN_ID})`
              : wallet.error}
          </p>
        )}
      </header>

      <section className="panel" aria-label="Posición">
        <h2 className="panel-title">Tu posición</h2>
        <dl className="stats">
          <div>
            <dt>Stake</dt>
            <dd data-testid="staked">
              {formatToken(snap.staked, dec)} {snap.stakeSymbol}
            </dd>
          </div>
          <div>
            <dt>Earned</dt>
            <dd data-testid="earned">
              {formatToken(snap.earned, dec)} {snap.rewardSymbol}
            </dd>
          </div>
          <div>
            <dt>Wallet</dt>
            <dd>
              {formatToken(snap.walletStake, dec)} {snap.stakeSymbol}
            </dd>
          </div>
          <div>
            <dt>Unlock</dt>
            <dd data-testid="unlock">
              {staking.lockupActive
                ? formatUnlock(snap.unlockTime)
                : snap.staked > 0n
                  ? "Libre"
                  : "—"}
            </dd>
          </div>
        </dl>
        <p className="muted tiny">
          Pool TVL: {formatToken(snap.totalSupply, dec)} · periodo hasta{" "}
          {formatUnlock(snap.periodFinish)}
        </p>
      </section>

      <section className="panel" aria-label="Acciones">
        <h2 className="panel-title">Acciones</h2>
        <label className="field">
          <span>Cantidad ({snap.stakeSymbol})</span>
          <input
            data-testid="amount-input"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            inputMode="decimal"
            placeholder="0.0"
            disabled={!wallet.address || !!staking.busy}
          />
        </label>
        <div className="actions">
          <button
            type="button"
            className="btn btn-primary"
            disabled={!wallet.address || !!staking.busy}
            onClick={() => void staking.stake(amount)}
          >
            {staking.busy === "stake" ? "…" : "Stake"}
          </button>
          <button
            type="button"
            className="btn"
            disabled={!wallet.address || !!staking.busy || staking.lockupActive}
            title={staking.lockupActive ? "Lockup activo" : undefined}
            onClick={() => void staking.withdraw(amount)}
          >
            {staking.busy === "withdraw" ? "…" : "Withdraw"}
          </button>
          <button
            type="button"
            className="btn"
            disabled={!wallet.address || !!staking.busy || snap.earned === 0n}
            onClick={() => void staking.getReward()}
          >
            {staking.busy === "getReward" ? "…" : "Claim reward"}
          </button>
          <button
            type="button"
            className="btn btn-ghost"
            disabled={!wallet.address || !!staking.busy || staking.lockupActive}
            onClick={() => void staking.exit()}
          >
            {staking.busy === "exit" ? "…" : "Exit"}
          </button>
        </div>
        {staking.lockupActive && (
          <p className="warn" data-testid="lockup-warning">
            Lockup activo hasta {formatUnlock(snap.unlockTime)}. Puedes claim;
            withdraw/exit están bloqueados.
          </p>
        )}
        {staking.error && (
          <p className="error-box" role="alert">
            {staking.error}
          </p>
        )}
        {staking.txHash && (
          <p className="muted tiny">
            Tx: <code>{shortAddress(staking.txHash, 6)}</code>
          </p>
        )}
        <button
          type="button"
          className="btn btn-ghost tiny-btn"
          onClick={() => void staking.refresh()}
        >
          Refrescar
        </button>
      </section>
    </div>
  );
}
