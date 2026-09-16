// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
// Upgrades：按 artifact 名部署，ffi 跑 upgrades-core 校验（脚本用）
// UnsafeUpgrades：传入已 new 的 implementation 地址，跳过校验，不需要 ffi / forge clean（测试、coverage 用）
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {MyERC721UpgradeableNFT} from "../../src/upgradeable/MyERC721UpgradeableNFT.sol";
import {MyERC721UpgradeableNFTV2} from "../../src/upgradeable/MyERC721UpgradeableNFTV2.sol";

contract MyERC721UpgradeableNFTTest is Test {
    MyERC721UpgradeableNFT public nft; // proxy
    MyERC721UpgradeableNFT public implementation;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    string constant URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";

    function setUp() public {
        implementation = new MyERC721UpgradeableNFT();
        nft = _wrap(address(implementation), owner);
    }

    function _wrap(address impl, address initialOwner) internal returns (MyERC721UpgradeableNFT) {
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            impl, abi.encodeCall(MyERC721UpgradeableNFT.initialize, (initialOwner))
        );
        return MyERC721UpgradeableNFT(proxy);
    }

    function test_Mint_WithURI() public {
        uint256 tokenId = nft.mint(alice, URI);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.tokenURI(tokenId), URI);
        assertEq(nft.balanceOf(alice), 1);
        // ERC721 默认没有 totalSupply；tokenId 从 0 递增且合约无 burn，nextTokenId 即已发行数量
        assertEq(nft.nextTokenId(), 1);
        assertEq(nft.owner(), owner);
    }

    function test_Mint_IncrementsTokenId() public {
        uint256 id0 = nft.mint(alice, URI);
        uint256 id1 = nft.mint(bob, "ipfs://QmOther");

        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(nft.ownerOf(id0), alice);
        assertEq(nft.ownerOf(id1), bob);
        assertEq(nft.nextTokenId(), 2);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert();
        nft.mint(address(0), URI);
    }

    function test_RevertWhen_InitializeTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        nft.initialize(owner);
    }

    function test_RevertWhen_InitializeImplementation() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(owner);
    }

    function test_RevertWhen_InitializeZeroOwner() public {
        MyERC721UpgradeableNFT impl = new MyERC721UpgradeableNFT();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        UnsafeUpgrades.deployUUPSProxy(
            address(impl), abi.encodeCall(MyERC721UpgradeableNFT.initialize, (address(0)))
        );

        address proxy2 = UnsafeUpgrades.deployUUPSProxy(
            address(impl), abi.encodeCall(MyERC721UpgradeableNFT.initialize, (owner))
        );
        MyERC721UpgradeableNFT nft2 = MyERC721UpgradeableNFT(proxy2);
        assertEq(nft2.owner(), owner);
    }

    function test_Upgrade_PreservesState() public {
        uint256 tokenId = nft.mint(alice, URI);

        MyERC721UpgradeableNFTV2 v2 = new MyERC721UpgradeableNFTV2();
        vm.prank(owner);
        nft.upgradeToAndCall(
            address(v2),
            abi.encodeCall(MyERC721UpgradeableNFTV2.initializeV2, ())
        );

        MyERC721UpgradeableNFTV2 upgraded = MyERC721UpgradeableNFTV2(address(nft));
        assertEq(upgraded.ownerOf(tokenId), alice);
        assertEq(upgraded.tokenURI(tokenId), URI);
        assertEq(upgraded.nextTokenId(), 1);
        assertEq(upgraded.totalSupply(), 1);
        assertEq(upgraded.owner(), owner);

        uint256 nextId = upgraded.mint(bob, "ipfs://QmOther");
        assertEq(nextId, 1);
        assertEq(upgraded.ownerOf(nextId), bob);
        assertEq(upgraded.nextTokenId(), 2);
        assertEq(upgraded.totalSupply(), 2);

        vm.prank(owner);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        upgraded.initializeV2();
    }

    function test_RevertWhen_NonOwnerUpgrade() public {
        MyERC721UpgradeableNFTV2 v2 = new MyERC721UpgradeableNFTV2();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        nft.upgradeToAndCall(address(v2), "");
    }

    function testFuzz_Mint_AssignsToEoa(address to) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);

        uint256 tokenId = nft.mint(to, URI);
        assertEq(nft.ownerOf(tokenId), to);
        assertEq(nft.tokenURI(tokenId), URI);
        assertEq(nft.balanceOf(to), 1);
        assertEq(nft.nextTokenId(), 1);
    }
}
