// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// SimpleVault — ERC-4626 储蓄金库
// 存入 vASSET 得到 svASSET 份额。donate 额外资产且不增发份额，份额价格上涨。
//
// forge script script/erc-4626/DeploySimpleVault.s.sol:DeploySimpleVault \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {SimpleVault} from "../../src/erc-4626/SimpleVault.sol";
import {VaultAsset} from "../../src/erc-4626/VaultAsset.sol";

contract DeploySimpleVault is BaseScript {
    function run() public broadcaster {
        VaultAsset asset = new VaultAsset();
        SimpleVault vault = new SimpleVault(asset);
        saveContract("VaultAsset", address(asset));
        saveContract("SimpleVault", address(vault));

        console.log("VaultAsset: ", address(asset));
        console.log("SimpleVault:", address(vault));
    }
}
