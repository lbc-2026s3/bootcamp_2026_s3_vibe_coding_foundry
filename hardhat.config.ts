import { existsSync } from "node:fs";
import { loadEnvFile } from "node:process";

import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable, defineConfig } from "hardhat/config";

// Reuse the same .env Foundry already uses (SEPOLIA_PRIVATE_KEY, etc.)
if (existsSync(".env")) {
  loadEnvFile(".env");
}

/** Parse Foundry's FOUNDRY_RPC_ENDPOINTS={sepolia="https://..."} inline table. */
function foundryRpc(name: string): string | undefined {
  const raw = process.env.FOUNDRY_RPC_ENDPOINTS;
  if (raw === undefined) {
    return undefined;
  }
  const match = raw.match(new RegExp(`${name}\\s*=\\s*"([^"]+)"`));
  return match?.[1];
}

const sepoliaRpc = process.env.SEPOLIA_RPC_URL ?? foundryRpc("sepolia");

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin],
  paths: {
    sources: "./src",
    // Foundry owns Solidity unit/fuzz tests under ./test
    tests: {
      solidity: "./hh-test",
      nodejs: "./hh-test",
    },
    // Keep Hardhat cache off Foundry's ./cache
    cache: "./hh-cache",
    artifacts: "./artifacts",
  },
  solidity: {
    profiles: {
      default: {
        version: "0.8.25",
        settings: {
          evmVersion: "cancun",
          optimizer: {
            enabled: false,
            runs: 200,
          },
        },
      },
      production: {
        version: "0.8.25",
        settings: {
          evmVersion: "cancun",
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    localhost: {
      type: "http",
      chainType: "l1",
      url: configVariable("LOCALHOST_RPC_URL", {
        default: "http://127.0.0.1:8545",
      }),
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url:
        sepoliaRpc === undefined
          ? configVariable("SEPOLIA_RPC_URL")
          : configVariable("SEPOLIA_RPC_URL", { default: sepoliaRpc }),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
  },
  verify: {
    etherscan: {
      apiKey: configVariable("ETHERSCAN_API_KEY"),
    },
  },
});
