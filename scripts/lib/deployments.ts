import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

import type { Address } from "viem";

export type DeploymentRecord = {
  address: Address;
  deployer: Address;
  chainId: number;
  blockNumber: number;
  deployedAt: string;
};

export function deploymentFile(name: string, chainId: number): string {
  return path.join("deployments", name, `${name}_${chainId}.json`);
}

function formatBeijingTime(date: Date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);

  const get = (type: Intl.DateTimeFormatPartTypes): string =>
    parts.find((part) => part.type === type)?.value ?? "";

  return `${get("year")}-${get("month")}-${get("day")} ${get("hour")}:${get("minute")}:${get("second")} CST`;
}

export async function saveContract(
  name: string,
  address: Address,
  deployer: Address,
  chainId: number,
  blockNumber: bigint,
): Promise<string> {
  const record: DeploymentRecord = {
    address,
    deployer,
    chainId,
    blockNumber: Number(blockNumber),
    deployedAt: formatBeijingTime(),
  };

  const filePath = deploymentFile(name, chainId);
  await mkdir(path.dirname(filePath), { recursive: true });
  await writeFile(filePath, `${JSON.stringify(record, null, 2)}\n`);
  return filePath;
}

export async function loadContract(
  name: string,
  chainId: number,
): Promise<DeploymentRecord> {
  const filePath = deploymentFile(name, chainId);
  try {
    const raw = await readFile(filePath, "utf8");
    return JSON.parse(raw) as DeploymentRecord;
  } catch {
    throw new Error(
      `No deployment found for ${name} on chain ${chainId} (${filePath}). Deploy first.`,
    );
  }
}

export function asAddress(value: string): Address {
  if (!value.startsWith("0x") || value.length !== 42) {
    throw new Error(`Invalid address: ${value}`);
  }
  return value as Address;
}
