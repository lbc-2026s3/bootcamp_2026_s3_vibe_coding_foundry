// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PredictionMarket} from "../../src/prediction/PredictionMarket.sol";
import {OutcomeToken} from "../../src/prediction/OutcomeToken.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredictionMarketTest is Test {
    MockUSDC internal usdc;
    PredictionMarket internal market;
    address internal oracle = makeAddr("oracle");
    address internal alice = makeAddr("alice");
    uint256 internal deadline;

    function setUp() public {
        usdc = new MockUSDC();
        deadline = block.timestamp + 7 days;
        market = new PredictionMarket("Will ETH > 5k?", address(usdc), deadline, oracle);
        usdc.mint(alice, 1_000_000e6);
    }

    function test_ConstructorDeploysOutcomeTokens() public view {
        assertEq(market.oracle(), oracle);
        assertEq(address(market.collateral()), address(usdc));
        assertEq(OutcomeToken(address(market.yesToken())).decimals(), 6);
        assertEq(OutcomeToken(address(market.yesToken())).market(), address(market));
    }

    function test_SplitMintsEqualYesAndNo() public {
        vm.startPrank(alice);
        usdc.approve(address(market), 100e6);
        market.split(100e6);
        vm.stopPrank();

        assertEq(market.yesToken().balanceOf(alice), 100e6);
        assertEq(market.noToken().balanceOf(alice), 100e6);
        assertEq(usdc.balanceOf(address(market)), 100e6);
    }

    function test_MergeBurnsAndReturnsCollateral() public {
        vm.startPrank(alice);
        usdc.approve(address(market), 100e6);
        market.split(100e6);
        market.merge(40e6);
        vm.stopPrank();

        assertEq(market.yesToken().balanceOf(alice), 60e6);
        assertEq(market.noToken().balanceOf(alice), 60e6);
        assertEq(usdc.balanceOf(alice), 1_000_000e6 - 60e6);
    }

    function test_RevertWhen_SplitAfterDeadline() public {
        vm.warp(deadline);
        vm.startPrank(alice);
        usdc.approve(address(market), 1e6);
        vm.expectRevert(PredictionMarket.MarketClosed.selector);
        market.split(1e6);
        vm.stopPrank();
    }
}
