// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console} from "forge-std/Script.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {PredictionMarketFactory} from "../../src/prediction/PredictionMarketFactory.sol";
import {PredictionMarket} from "../../src/prediction/PredictionMarket.sol";

contract DeployMockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1_000_000_000e6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract DeployPredictionMarket is BaseScript {
    function run() public broadcaster {
        address collateral = vm.envOr("COLLATERAL", address(0));
        if (collateral == address(0)) {
            DeployMockUSDC mock = new DeployMockUSDC();
            collateral = address(mock);
            saveContract("MockUSDC", collateral);
            console.log("MockUSDC: ", collateral);
        }

        PredictionMarketFactory factory = new PredictionMarketFactory();
        saveContract("PredictionMarketFactory", address(factory));

        string memory question = vm.envOr("QUESTION", string("Demo: ETH above 5000 by deadline?"));
        uint256 marketDeadline = vm.envOr("DEADLINE", uint256(block.timestamp + 7 days));
        address oracleAddr = vm.envOr("ORACLE", deployer);

        address marketAddr = factory.createMarket(question, collateral, marketDeadline, oracleAddr);
        PredictionMarket m = PredictionMarket(marketAddr);

        saveContract("PredictionMarket", marketAddr);
        saveContract("YesToken", address(m.yesToken()));
        saveContract("NoToken", address(m.noToken()));

        console.log("Factory: ", address(factory));
        console.log("Market:  ", marketAddr);
        console.log("YES:     ", address(m.yesToken()));
        console.log("NO:      ", address(m.noToken()));
        console.log("deadline:", marketDeadline);
    }
}
