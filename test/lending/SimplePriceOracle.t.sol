// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SimplePriceOracle} from "../../src/lending/SimplePriceOracle.sol";

contract SimplePriceOracleTest is Test {
    SimplePriceOracle internal oracle;
    address internal weth = makeAddr("weth");
    address internal alice = makeAddr("alice");

    function setUp() public {
        oracle = new SimplePriceOracle(address(this));
    }

    function test_ownerSetsPrice() public {
        oracle.setPrice(weth, 2000e18);
        assertEq(oracle.getPrice(weth), 2000e18);
    }

    function test_unsetPriceIsZero() public view {
        assertEq(oracle.getPrice(weth), 0);
    }

    function test_zeroPriceReverts() public {
        vm.expectRevert(SimplePriceOracle.ZeroPrice.selector);
        oracle.setPrice(weth, 0);
    }

    function test_nonOwnerCannotSetPrice() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        oracle.setPrice(weth, 2000e18);
    }
}
