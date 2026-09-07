import { network } from "hardhat";

export async function connect() {
  const { viem, networkName } = await network.create();
  const publicClient = await viem.getPublicClient();
  const [wallet] = await viem.getWalletClients();

  if (wallet === undefined) {
    throw new Error(
      `No wallet accounts configured for network "${networkName}". Set SEPOLIA_PRIVATE_KEY in .env, or use anvil's unlocked accounts on localhost.`,
    );
  }

  const chainId = await publicClient.getChainId();
  const deployer = wallet.account.address;

  return { viem, networkName, publicClient, wallet, chainId, deployer };
}
