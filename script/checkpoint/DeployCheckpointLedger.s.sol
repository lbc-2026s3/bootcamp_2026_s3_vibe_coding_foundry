// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// CheckpointLedger — OpenZeppelin Checkpoints.Trace208 教学示例
// 无构造参数；部署后可用 mint / burn / transfer 写入按 block.number 索引的历史。
//
// forge script script/checkpoint/DeployCheckpointLedger.s.sol:DeployCheckpointLedger \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {CheckpointLedger} from "../../src/checkpoint/CheckpointLedger.sol";

contract DeployCheckpointLedger is BaseScript {
    CheckpointLedger public ledger;

    function run() public broadcaster {
        ledger = new CheckpointLedger();

        saveContract("CheckpointLedger", address(ledger));

        console.log("CheckpointLedger: ", address(ledger));
        console.log("totalSupply:      ", ledger.totalSupply());
    }
}
