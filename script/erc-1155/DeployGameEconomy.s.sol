// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ---------------------------------------------------------------------------
// GameEconomy — 游戏货币和道具
//
// forge script script/erc-1155/DeployGameEconomy.s.sol:DeployGameEconomy \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {GameEconomy} from "../../src/erc-1155/GameEconomy.sol";

contract DeployGameEconomy is BaseScript {
    GameEconomy public game;

    function run() public broadcaster {
        game = new GameEconomy();
        saveContract("GameEconomy", address(game));

        console.log("GameEconomy:", address(game));
        console.log("owner:      ", game.owner());
        console.log("sword price:", game.SWORD_PRICE());
    }
}
