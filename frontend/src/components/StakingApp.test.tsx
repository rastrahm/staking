import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { StakingApp } from "@/components/StakingApp";

const connect = vi.fn();

vi.mock("@/hooks/useWallet", () => ({
  useWallet: () => ({
    address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    chainId: 31337,
    connecting: false,
    error: null,
    provider: null,
    signer: {},
    wrongChain: false,
    connect,
    disconnect: vi.fn(),
  }),
}));

vi.mock("@/hooks/useStaking", () => ({
  useStaking: () => ({
    snap: {
      staked: 0n,
      earned: 0n,
      walletStake: 0n,
      allowance: 0n,
      unlockTime: 0n,
      lockupDuration: 0n,
      totalSupply: 0n,
      periodFinish: 0n,
      stakeSymbol: "STK",
      rewardSymbol: "RWD",
      decimals: 18,
    },
    busy: null,
    error: null,
    txHash: null,
    refresh: vi.fn(),
    approve: vi.fn(),
    stake: vi.fn(),
    withdraw: vi.fn(),
    getReward: vi.fn(),
    exit: vi.fn(),
    lockupActive: false,
  }),
}));

describe("StakingApp", () => {
  const env = {
    NEXT_PUBLIC_RPC_URL: "http://127.0.0.1:8545",
    NEXT_PUBLIC_CHAIN_ID: "31337",
    NEXT_PUBLIC_STAKING_ADDRESS: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
    NEXT_PUBLIC_STAKE_TOKEN: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    NEXT_PUBLIC_REWARD_TOKEN: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  };

  beforeEach(() => {
    cleanup();
    for (const [k, v] of Object.entries(env)) {
      vi.stubEnv(k, v);
    }
  });

  afterEach(() => {
    cleanup();
    vi.unstubAllEnvs();
  });

  it("muestra brand y wallet conectada", () => {
    render(<StakingApp />);
    expect(screen.getByText("StakingRewards")).toBeInTheDocument();
    expect(screen.getByTestId("wallet-address")).toBeInTheDocument();
    expect(screen.getByTestId("earned")).toHaveTextContent("0");
  });

  it("permite escribir cantidad", async () => {
    const user = userEvent.setup();
    render(<StakingApp />);
    const input = screen.getByTestId("amount-input");
    expect(input).not.toBeDisabled();
    await user.clear(input);
    await user.type(input, "10");
    expect(input).toHaveValue("10");
  });
});
