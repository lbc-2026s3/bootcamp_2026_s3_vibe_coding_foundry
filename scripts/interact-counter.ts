import { asAddress, loadContract, saveContract } from "./lib/deployments.ts";
import { connect } from "./lib/connect.ts";
import type { Address } from "viem";

const { viem, networkName, publicClient, chainId, deployer } = await connect();

async function resolveCounterAddress(): Promise<Address> {
  const fromEnv = process.env.COUNTER_ADDRESS;
  let candidate: Address | undefined;
  if (fromEnv !== undefined) {
    candidate = asAddress(fromEnv);
  } else {
    try {
      candidate = (await loadContract("Counter", chainId)).address;
    } catch {
      candidate = undefined;
    }
  }

  if (candidate !== undefined) {
    const code = await publicClient.getCode({ address: candidate });
    if (code !== undefined && code !== "0x") {
      return candidate;
    }
    console.log(`No bytecode at ${candidate} on this network; deploying a new Counter`);
  }

  const deployed = await viem.deployContract("Counter");
  const blockNumber = await publicClient.getBlockNumber();
  await saveContract("Counter", deployed.address, deployer, chainId, blockNumber);
  console.log(`Counter deployed at ${deployed.address}`);
  return deployed.address;
}

const address = await resolveCounterAddress();
const newNumber = BigInt(process.env.NUMBER ?? "42");

const counter = await viem.getContractAt("Counter", address);

console.log(`Interacting with Counter at ${address} on ${networkName}`);

const before = await counter.read.number();
console.log(`number() before: ${before}`);

const setHash = await counter.write.setNumber([newNumber]);
await publicClient.waitForTransactionReceipt({ hash: setHash });
console.log(`setNumber(${newNumber}) tx: ${setHash}`);

const incHash = await counter.write.increment();
await publicClient.waitForTransactionReceipt({ hash: incHash });
console.log(`increment() tx: ${incHash}`);

const after = await counter.read.number();
console.log(`number() after: ${after}`);
