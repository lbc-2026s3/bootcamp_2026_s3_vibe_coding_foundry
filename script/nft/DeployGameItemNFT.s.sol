// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// GameItemNFT — 带耐久 / 装备状态的游戏道具 ERC721
//
// forge script script/nft/DeployGameItemNFT.s.sol:DeployGameItemNFT \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {GameItemNFT} from "../../src/nft/GameItemNFT.sol";

contract DeployGameItemNFT is BaseScript {
    GameItemNFT public nft;

    function run() public broadcaster {
        nft = new GameItemNFT();
        saveContract("GameItemNFT", address(nft));

        console.log("GameItemNFT:", address(nft));
        console.log("name:       ", nft.name());
        console.log("symbol:     ", nft.symbol());
        console.log("owner:      ", nft.owner());
    }
}
