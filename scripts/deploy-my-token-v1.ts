import { connect } from "./lib/connect.ts";
import { saveContract } from "./lib/deployments.ts";

const { viem, networkName, publicClient, chainId, deployer } = await connect();

console.log(`Deploying MyTokenV1 on ${networkName} (chainId ${chainId}) from ${deployer}`);

const token = await viem.deployContract("MyTokenV1");
const blockNumber = await publicClient.getBlockNumber();
const filePath = await saveContract(
  "MyTokenV1",
  token.address,
  deployer,
  chainId,
  blockNumber,
);

const supply = await token.read.totalSupply();
console.log(`MyTokenV1 deployed at ${token.address}`);
console.log(`totalSupply: ${supply}`);
console.log(`Saved ${filePath}`);
