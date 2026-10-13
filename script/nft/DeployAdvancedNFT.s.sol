// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// ---------------------------------------------------------------------------
// AdvancedNFT — 带链上属性的 ERC721
//
// forge script script/nft/DeployAdvancedNFT.s.sol:DeployAdvancedNFT \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {AdvancedNFT} from "../../src/nft/AdvancedNFT.sol";

contract DeployAdvancedNFT is BaseScript {
    AdvancedNFT public nft;

    function run() public broadcaster {
        nft = new AdvancedNFT();
        saveContract("AdvancedNFT", address(nft));

        console.log("AdvancedNFT:", address(nft));
        console.log("name:       ", nft.name());
        console.log("symbol:     ", nft.symbol());
        console.log("owner:      ", nft.owner());
    }
}
