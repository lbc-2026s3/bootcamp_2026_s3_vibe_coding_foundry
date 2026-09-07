import { connect } from "./lib/connect.ts";
import { saveContract } from "./lib/deployments.ts";

const { viem, networkName, publicClient, chainId, deployer } = await connect();

console.log(
  `Deploying MyTokenERC1363 + TokenBankERC1363 on ${networkName} (chainId ${chainId}) from ${deployer}`,
);

const token = await viem.deployContract("MyTokenERC1363");
const bank = await viem.deployContract("TokenBankERC1363", [token.address]);
const blockNumber = await publicClient.getBlockNumber();

const tokenPath = await saveContract(
  "MyTokenERC1363",
  token.address,
  deployer,
  chainId,
  blockNumber,
);
const bankPath = await saveContract(
  "TokenBankERC1363",
  bank.address,
  deployer,
  chainId,
  blockNumber,
);

console.log(`MyTokenERC1363 deployed at ${token.address}`);
console.log(`TokenBankERC1363 deployed at ${bank.address}`);
console.log(`Saved ${tokenPath}`);
console.log(`Saved ${bankPath}`);
