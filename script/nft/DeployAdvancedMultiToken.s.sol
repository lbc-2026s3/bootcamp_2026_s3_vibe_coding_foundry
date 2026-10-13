// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// ---------------------------------------------------------------------------
// AdvancedMultiToken — 多种类 ERC1155
//
// forge script script/nft/DeployAdvancedMultiToken.s.sol:DeployAdvancedMultiToken \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {AdvancedMultiToken} from "../../src/nft/AdvancedMultiToken.sol";

contract DeployAdvancedMultiToken is BaseScript {
    AdvancedMultiToken public token;

    function run() public broadcaster {
        token = new AdvancedMultiToken();
        saveContract("AdvancedMultiToken", address(token));

        console.log("AdvancedMultiToken:", address(token));
        console.log("owner:             ", token.owner());
        console.log("paused:            ", token.paused());
    }
}
