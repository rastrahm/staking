import { describe, expect, it } from "vitest";
import { parsePublicEnv, safeParsePublicEnv } from "@/lib/env";
import { formatToken, parseTokenInput, shortAddress } from "@/lib/format";
import { humanizeError } from "@/lib/errors";

const valid = {
  NEXT_PUBLIC_RPC_URL: "http://127.0.0.1:8545",
  NEXT_PUBLIC_CHAIN_ID: "31337",
  NEXT_PUBLIC_STAKING_ADDRESS: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
  NEXT_PUBLIC_STAKE_TOKEN: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  NEXT_PUBLIC_REWARD_TOKEN: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
};

describe("parsePublicEnv", () => {
  it("acepta env Anvil válido", () => {
    const env = parsePublicEnv(valid);
    expect(env.NEXT_PUBLIC_CHAIN_ID).toBe(31337);
    expect(env.NEXT_PUBLIC_STAKING_ADDRESS).toMatch(/^0x/i);
  });

  it("rechaza address inválida", () => {
    const r = safeParsePublicEnv({ ...valid, NEXT_PUBLIC_STAKING_ADDRESS: "0x123" });
    expect(r.success).toBe(false);
  });
});

describe("format helpers", () => {
  it("formatea y parsea tokens", () => {
    expect(formatToken(1_500_000_000_000_000_000n)).toBe("1.5");
    expect(parseTokenInput("2.5")).toBe(2_500_000_000_000_000_000n);
    expect(() => parseTokenInput("0")).toThrow();
    expect(shortAddress("0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9")).toBe(
      "0xDc64…F6C9",
    );
  });
});

describe("humanizeError", () => {
  it("mapea LockupActive", () => {
    expect(humanizeError({ shortMessage: "execution reverted: LockupActive()" })).toMatch(
      /lockup/i,
    );
  });
});
