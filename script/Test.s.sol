// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// forge script script/Test.s.sol --rpc-url local --broadcast \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt

import {console} from "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.s.sol";
import {Test} from "../src/Test.sol";

contract DeployTest is BaseScript {
    function run() public broadcaster {
        Test test = new Test();
        saveContract("Test", address(test));

        console.log("Test:", address(test));
        console.log("slot0 a:", test.INITIAL_A());
        console.log("slot0 c:", test.INITIAL_C());
        console.log("slot1 b / balances key:", test.DEMO_ACCOUNT());
        console.log("balances[key]:", test.INITIAL_BALANCE());
    }
}
