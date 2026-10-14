// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// ArtNFT — 可标价出售的 ERC721，二级市场版税由创作者自行提取
//
// forge script script/nft/DeployArtNFT.s.sol:DeployArtNFT \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {ArtNFT} from "../../src/nft/ArtNFT.sol";

contract DeployArtNFT is BaseScript {
    ArtNFT public nft;

    function run() public broadcaster {
        nft = new ArtNFT();
        saveContract("ArtNFT", address(nft));

        console.log("ArtNFT: ", address(nft));
        console.log("name:   ", nft.name());
        console.log("symbol: ", nft.symbol());
        console.log("owner:  ", nft.owner());
    }
}
