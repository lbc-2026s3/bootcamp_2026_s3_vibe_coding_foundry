import { connect } from "./lib/connect.ts";
import { saveContract } from "./lib/deployments.ts";

const { viem, networkName, publicClient, chainId, deployer } = await connect();

console.log(`Deploying Counter on ${networkName} (chainId ${chainId}) from ${deployer}`);

const counter = await viem.deployContract("Counter");
const blockNumber = await publicClient.getBlockNumber();
const filePath = await saveContract(
  "Counter",
  counter.address,
  deployer,
  chainId,
  blockNumber,
);

console.log(`Counter deployed at ${counter.address}`);
console.log(`Saved ${filePath}`);
