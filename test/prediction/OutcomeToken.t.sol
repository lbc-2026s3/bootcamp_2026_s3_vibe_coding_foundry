// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OutcomeToken} from "../../src/prediction/OutcomeToken.sol";

contract OutcomeTokenTest is Test {
    address internal market = makeAddr("market");
    address internal alice = makeAddr("alice");
    OutcomeToken internal token;

    function setUp() public {
        token = new OutcomeToken("Yes", "YES", 6, market);
    }

    function test_DecimalsMatchConstructor() public view {
        assertEq(token.decimals(), 6);
    }

    function test_MarketCanMintAndBurn() public {
        vm.prank(market);
        token.mint(alice, 100e6);
        assertEq(token.balanceOf(alice), 100e6);

        vm.prank(market);
        token.burn(alice, 40e6);
        assertEq(token.balanceOf(alice), 60e6);
    }

    function test_RevertWhen_NonMarketMints() public {
        vm.prank(alice);
        vm.expectRevert(OutcomeToken.NotMarket.selector);
        token.mint(alice, 1);
    }

    function test_RevertWhen_ZeroMarket() public {
        vm.expectRevert(OutcomeToken.ZeroAddress.selector);
        new OutcomeToken("Yes", "YES", 6, address(0));
    }
}
