// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ---------------------------------------------------------------------------
// DeFiVault — LP / 治理代币锁仓，按档位发放 ERC1155 奖励
//
// forge script script/erc-1155/DeployDeFiVault.s.sol:DeployDeFiVault \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {DeFiVault} from "../../src/erc-1155/DeFiVault.sol";

contract DeployDeFiVault is BaseScript {
    DeFiVault public vault;

    function run() public broadcaster {
        vault = new DeFiVault();
        saveContract("DeFiVault", address(vault));

        console.log("DeFiVault:", address(vault));
        console.log("owner:    ", vault.owner());
        console.log("30d APY:  ", vault.rewardRateFor(30 days));
        console.log("365d APY: ", vault.rewardRateFor(365 days));
    }
}
