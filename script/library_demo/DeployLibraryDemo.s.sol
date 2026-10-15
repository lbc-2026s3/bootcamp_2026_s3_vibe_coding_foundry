// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// ---------------------------------------------------------------------------
// InlineCalculator + LinkedCalculator
//
// LinkedMath 是 public 库。forge script 会先部署它，再把地址 link 进
// LinkedCalculator 的字节码。InlineMath 是 internal，不会单独部署。
//
// forge script script/library_demo/DeployLibraryDemo.s.sol:DeployLibraryDemo \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {InlineCalculator} from "../../src/library_demo/InlineCalculator.sol";
import {LinkedCalculator} from "../../src/library_demo/LinkedCalculator.sol";

contract DeployLibraryDemo is BaseScript {
    InlineCalculator public inlineCalc;
    LinkedCalculator public linkedCalc;

    function run() public broadcaster {
        inlineCalc = new InlineCalculator();
        linkedCalc = new LinkedCalculator();

        saveContract("InlineCalculator", address(inlineCalc));
        saveContract("LinkedCalculator", address(linkedCalc));

        console.log("InlineCalculator:", address(inlineCalc));
        console.log("LinkedCalculator:", address(linkedCalc));
    }
}
