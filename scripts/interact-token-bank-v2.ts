import { parseEther, type Address } from "viem";

import { asAddress, loadContract, saveContract } from "./lib/deployments.ts";
import { connect } from "./lib/connect.ts";

const { viem, networkName, publicClient, chainId, deployer } = await connect();

async function hasCode(address: Address): Promise<boolean> {
  const code = await publicClient.getCode({ address });
  return code !== undefined && code !== "0x";
}

async function resolvePair(): Promise<{ tokenAddress: Address; bankAddress: Address }> {
  const tokenFromEnv = process.env.TOKEN_ADDRESS;
  const bankFromEnv = process.env.BANK_ADDRESS;
  let tokenAddress = tokenFromEnv !== undefined ? asAddress(tokenFromEnv) : undefined;
  let bankAddress = bankFromEnv !== undefined ? asAddress(bankFromEnv) : undefined;

  if (tokenAddress === undefined) {
    try {
      tokenAddress = (await loadContract("MyTokenV1", chainId)).address;
    } catch {
      tokenAddress = undefined;
    }
  }
  if (bankAddress === undefined) {
    try {
      bankAddress = (await loadContract("TokenBankV2", chainId)).address;
    } catch {
      bankAddress = undefined;
    }
  }

  if (
    tokenAddress !== undefined &&
    bankAddress !== undefined &&
    (await hasCode(tokenAddress)) &&
    (await hasCode(bankAddress))
  ) {
    return { tokenAddress, bankAddress };
  }

  console.log("Token/bank not found on this network; deploying MyTokenV1 + TokenBankV2");
  const token = await viem.deployContract("MyTokenV1");
  const bank = await viem.deployContract("TokenBankV2", [token.address]);
  const blockNumber = await publicClient.getBlockNumber();
  await saveContract("MyTokenV1", token.address, deployer, chainId, blockNumber);
  await saveContract("TokenBankV2", bank.address, deployer, chainId, blockNumber);
  return { tokenAddress: token.address, bankAddress: bank.address };
}

const { tokenAddress, bankAddress } = await resolvePair();
const amount = parseEther(process.env.AMOUNT ?? "1");

const token = await viem.getContractAt("MyTokenV1", tokenAddress);
const bank = await viem.getContractAt("TokenBankV2", bankAddress);

console.log(`Interacting with TokenBankV2 at ${bankAddress} on ${networkName}`);
console.log(`Token: ${tokenAddress}`);

const approveHash = await token.write.approve([bankAddress, amount]);
await publicClient.waitForTransactionReceipt({ hash: approveHash });
console.log(`approve(${amount}) tx: ${approveHash}`);

const depositHash = await bank.write.deposit([amount]);
await publicClient.waitForTransactionReceipt({ hash: depositHash });
console.log(`deposit(${amount}) tx: ${depositHash}`);

const deposited = await bank.read.balances([deployer]);
console.log(`bank.balances(deployer): ${deposited}`);
