// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GameEconomy2} from "../src/erc-1155/GameEconomy2.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 GameEconomy2，登记货币和道具，并给部署人铸造一份初始资产。
contract GameEconomy2Script is BaseScript {
    uint256 internal constant CURRENCY_SUPPLY = 1_000_000;
    uint256 internal constant EQUIPMENT_SUPPLY = 1_000;
    uint256 internal constant CONSUMABLE_SUPPLY = 10_000;

    GameEconomy2 public game;

    function run() public broadcaster {
        game = new GameEconomy2();
        _createCatalog();
        game.mintItem(deployer, game.GOLD_COIN(), 1_000);
        game.mintItem(deployer, game.SILVER_COIN(), 500);
        game.mintItem(deployer, game.COPPER_COIN(), 500);
        game.mintItem(deployer, game.SWORD(), 1);
        game.mintItem(deployer, game.SHIELD(), 1);
        game.mintItem(deployer, game.POTION(), 5);
        game.mintItem(deployer, game.SCROLL(), 2);
        saveContract("GameEconomy2", address(game));
    }

    function _createCatalog() private {
        game.createItem(
            game.GOLD_COIN(), "Gold Coin", "currency", 1, 0, 0, true, CURRENCY_SUPPLY, "https://example.com/game/gold.json"
        );
        game.createItem(
            game.SILVER_COIN(),
            "Silver Coin",
            "currency",
            1,
            0,
            0,
            true,
            CURRENCY_SUPPLY,
            "https://example.com/game/silver.json"
        );
        game.createItem(
            game.COPPER_COIN(),
            "Copper Coin",
            "currency",
            1,
            0,
            0,
            true,
            CURRENCY_SUPPLY,
            "https://example.com/game/copper.json"
        );
        game.createItem(
            game.SWORD(), "Sword", "weapon", 1, 25, 0, false, EQUIPMENT_SUPPLY, "https://example.com/game/sword.json"
        );
        game.createItem(
            game.SHIELD(), "Shield", "armor", 1, 0, 20, false, EQUIPMENT_SUPPLY, "https://example.com/game/shield.json"
        );
        game.createItem(
            game.POTION(),
            "Potion",
            "consumable",
            1,
            0,
            0,
            true,
            CONSUMABLE_SUPPLY,
            "https://example.com/game/potion.json"
        );
        game.createItem(
            game.SCROLL(),
            "Scroll",
            "consumable",
            1,
            0,
            0,
            true,
            CONSUMABLE_SUPPLY,
            "https://example.com/game/scroll.json"
        );
    }
}
