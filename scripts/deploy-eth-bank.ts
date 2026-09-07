import { parseEther } from "viem";

import { connect } from "./lib/connect.ts";
import { saveContract } from "./lib/deployments.ts";

const { viem, networkName, publicClient, chainId, deployer } = await connect();

console.log(`Deploying ETHBank on ${networkName} (chainId ${chainId}) from ${deployer}`);

const bank = await viem.deployContract("ETHBank");
const blockNumber = await publicClient.getBlockNumber();
const filePath = await saveContract(
  "ETHBank",
  bank.address,
  deployer,
  chainId,
  blockNumber,
);

const depositValue = parseEther(process.env.DEPOSIT_ETH ?? "0.001");
const hash = await bank.write.deposit({ value: depositValue });
await publicClient.waitForTransactionReceipt({ hash });

const deposited = await bank.read.balances([deployer]);
console.log(`ETHBank deployed at ${bank.address}`);
console.log(`deposit() tx: ${hash}`);
console.log(`balances(deployer): ${deposited}`);
console.log(`Saved ${filePath}`);
