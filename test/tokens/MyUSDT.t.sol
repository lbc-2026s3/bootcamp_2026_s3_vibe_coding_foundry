// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MyUSDT} from "../../src/tokens/MyUSDT.sol";

contract MyUSDTTest is Test {
    MyUSDT public token;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");

    function setUp() public {
        vm.prank(admin);
        token = new MyUSDT();
        vm.deal(alice, 10 ether);
    }

    function test_Metadata() public view {
        assertEq(token.name(), "My USDT");
        assertEq(token.symbol(), "mUSDT");
        assertEq(token.decimals(), 6);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), admin);
    }

    function test_Mint_OneEthMintsOneToken() public {
        vm.prank(alice);
        token.mint{value: 1 ether}(alice);

        assertEq(token.balanceOf(alice), 1e6);
        assertEq(token.totalSupply(), 1e6);
        assertEq(token.totalReserves(), 1 ether);
        assertEq(alice.balance, 9 ether);
    }

    function test_Mint_RefundsDust() public {
        vm.prank(alice);
        token.mint{value: 1 ether + 100}(alice);

        assertEq(token.balanceOf(alice), 1e6);
        assertEq(token.totalReserves(), 1 ether);
        assertEq(alice.balance, 9 ether);
    }

    function test_Mint_RevertsWhenEthTooSmall() public {
        vm.prank(alice);
        vm.expectRevert("Need at least 0.000001 ETH");
        token.mint{value: 1e12 - 1}(alice);
    }

    function test_Burn_ReturnsEth() public {
        vm.startPrank(alice);
        token.mint{value: 2 ether}(alice);
        token.burn(1e6);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 1e6);
        assertEq(token.totalReserves(), 1 ether);
        assertEq(alice.balance, 9 ether);
    }

    function test_Pause_BlocksMintTransferAndBurn() public {
        vm.prank(alice);
        token.mint{value: 1 ether}(alice);

        vm.prank(admin);
        token.pause();

        vm.prank(alice);
        vm.expectRevert();
        token.mint{value: 1 ether}(alice);

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(admin, 1);

        vm.prank(alice);
        vm.expectRevert();
        token.burn(1e6);

        vm.prank(admin);
        token.unpause();

        vm.prank(alice);
        token.burn(1e6);
        assertEq(token.totalSupply(), 0);
        assertEq(alice.balance, 10 ether);
    }

    function test_Pause_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.pause();
    }
}
