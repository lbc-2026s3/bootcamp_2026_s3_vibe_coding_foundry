// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleVault} from "../../src/erc-4626/SimpleVault.sol";
import {VaultAsset} from "../../src/erc-4626/VaultAsset.sol";

contract SimpleVaultTest is Test {
    VaultAsset public asset;
    SimpleVault public vault;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    function _mintAndApprove(address user, uint256 amount) internal {
        asset.mint(user, amount);
        vm.prank(user);
        asset.approve(address(vault), amount);
    }

    function _deposit(address user, uint256 assets) internal {
        _mintAndApprove(user, assets);
        vm.prank(user);
        vault.deposit(assets, user);
    }

    function _donate(address donor, uint256 assets) internal {
        _mintAndApprove(donor, assets);
        vm.prank(donor);
        vault.donate(assets);
    }

    function setUp() public {
        asset = new VaultAsset();
        vault = new SimpleVault(asset);
    }

    function test_depositMintsOneToOneOnEmptyVault() public {
        uint256 assets = 100 ether;
        _mintAndApprove(alice, assets);
        uint256 preview = vault.previewDeposit(assets);

        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);

        assertEq(shares, assets);
        assertEq(shares, preview);
        assertEq(vault.balanceOf(alice), assets);
        assertEq(vault.totalAssets(), assets);
        assertEq(asset.balanceOf(alice), 0);
        assertEq(asset.balanceOf(address(vault)), assets);
    }

    function test_donateRaisesPriceWithoutMintingShares() public {
        _deposit(alice, 100 ether);
        uint256 sharesBefore = vault.totalSupply();
        uint256 assetsBefore = vault.convertToAssets(vault.balanceOf(alice));

        _donate(carol, 50 ether);

        assertEq(vault.totalSupply(), sharesBefore);
        assertEq(vault.balanceOf(carol), 0);
        assertEq(vault.balanceOf(alice), 100 ether);
        assertEq(vault.totalAssets(), 150 ether);
        assertGt(vault.convertToAssets(vault.balanceOf(alice)), assetsBefore);
    }

    function test_laterDepositorGetsFewerShares() public {
        _deposit(alice, 100 ether);
        _donate(carol, 100 ether);

        uint256 bobAssets = 100 ether;
        _mintAndApprove(bob, bobAssets);
        uint256 preview = vault.previewDeposit(bobAssets);

        vm.prank(bob);
        uint256 bobShares = vault.deposit(bobAssets, bob);

        assertEq(bobShares, preview);
        assertLt(bobShares, bobAssets);
        assertGt(vault.balanceOf(alice), bobShares);
    }

    function test_redeemReturnsPrincipalPlusProRataYield() public {
        _deposit(alice, 100 ether);
        _deposit(bob, 100 ether);
        _donate(carol, 100 ether);

        uint256 aliceShares = vault.balanceOf(alice);
        uint256 expected = vault.previewRedeem(aliceShares);
        assertGt(expected, 100 ether);

        vm.prank(alice);
        uint256 assetsOut = vault.redeem(aliceShares, alice, alice);

        assertEq(assetsOut, expected);
        assertEq(asset.balanceOf(alice), assetsOut);
        assertEq(vault.balanceOf(alice), 0);
        assertGt(vault.convertToAssets(vault.balanceOf(bob)), 100 ether);
    }

    function test_mintAndWithdrawMatchPreview() public {
        uint256 shares = 80 ether;
        uint256 assetsIn = vault.previewMint(shares);
        _mintAndApprove(alice, assetsIn);

        vm.prank(alice);
        uint256 paid = vault.mint(shares, alice);

        assertEq(paid, assetsIn);
        assertEq(vault.balanceOf(alice), shares);

        _donate(carol, 40 ether);

        uint256 assetsOut = 50 ether;
        uint256 sharesCost = vault.previewWithdraw(assetsOut);
        uint256 aliceAssetsBefore = asset.balanceOf(alice);

        vm.prank(alice);
        uint256 burned = vault.withdraw(assetsOut, alice, alice);

        assertEq(burned, sharesCost);
        assertEq(asset.balanceOf(alice), aliceAssetsBefore + assetsOut);
        assertEq(vault.balanceOf(alice), shares - burned);
    }

    function test_donateZeroReverts() public {
        vm.expectRevert(SimpleVault.ZeroAssets.selector);
        vault.donate(0);
    }
}
