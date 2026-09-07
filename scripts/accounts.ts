import { connect } from "./lib/connect.ts";

const { networkName, publicClient, wallet } = await connect();
const address = wallet.account.address;
const balance = await publicClient.getBalance({ address });

console.log(`Network: ${networkName}`);
console.log(`Account: ${address}`);
console.log(`Balance: ${balance} wei`);
