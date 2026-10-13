// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// ---------------------------------------------------------------------------
// AdvancedNFT — 带链上属性的 ERC721
//
// forge script script/nft/DeployAdvancedNFT.s.sol \
//   --broadcast --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY \
//   --evm-version amsterdam \
//   --gas-estimate-multiplier 120
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
