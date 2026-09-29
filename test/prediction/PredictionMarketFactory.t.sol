// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PredictionMarketFactory} from "../../src/prediction/PredictionMarketFactory.sol";
import {PredictionMarket} from "../../src/prediction/PredictionMarket.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}
    function decimals() public pure override returns (uint8) { return 6; }
}

contract PredictionMarketFactoryTest is Test {
    PredictionMarketFactory internal factory;
    MockUSDC internal usdc;
    address internal alice = makeAddr("alice");

    function setUp() public {
        factory = new PredictionMarketFactory();
        usdc = new MockUSDC();
    }

    function test_CreateMarketRegistersAndDefaultsOracle() public {
        uint256 marketDeadline = block.timestamp + 3 days;
        vm.prank(alice);
        address m = factory.createMarket("Q?", address(usdc), marketDeadline, address(0));

        assertEq(factory.marketCount(), 1);
        assertEq(factory.markets(0), m);
        assertEq(PredictionMarket(m).oracle(), alice);
        assertEq(PredictionMarket(m).deadline(), marketDeadline);
    }
}
