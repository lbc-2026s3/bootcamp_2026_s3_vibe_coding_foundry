import { connect } from "./lib/connect.ts";
import { saveContract } from "./lib/deployments.ts";

const { viem, networkName, publicClient, chainId, deployer } = await connect();

console.log(
  `Deploying MyTokenV1 + TokenBankV2 on ${networkName} (chainId ${chainId}) from ${deployer}`,
);

const token = await viem.deployContract("MyTokenV1");
const bank = await viem.deployContract("TokenBankV2", [token.address]);
const blockNumber = await publicClient.getBlockNumber();

const tokenPath = await saveContract(
  "MyTokenV1",
  token.address,
  deployer,
  chainId,
  blockNumber,
);
const bankPath = await saveContract(
  "TokenBankV2",
  bank.address,
  deployer,
  chainId,
  blockNumber,
);

console.log(`MyTokenV1 deployed at ${token.address}`);
console.log(`TokenBankV2 deployed at ${bank.address}`);
console.log(`Saved ${tokenPath}`);
console.log(`Saved ${bankPath}`);
