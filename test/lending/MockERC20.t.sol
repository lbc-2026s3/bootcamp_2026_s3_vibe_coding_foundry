// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../src/lending/MockERC20.sol";

contract MockERC20Test is Test {
    function test_mintIncreasesBalance() public {
        MockERC20 token = new MockERC20("USD Coin", "USDC");
        address alice = makeAddr("alice");

        token.mint(alice, 1_000e18);

        assertEq(token.decimals(), 18);
        assertEq(token.balanceOf(alice), 1_000e18);
        assertEq(token.totalSupply(), 1_000e18);
    }
}
