// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyERC721NFT} from "../src/MyERC721NFT.sol";

contract MyERC721NFTTest is Test {
    MyERC721NFT public nft;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    string constant URI =
        "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";

    function setUp() public {
        nft = new MyERC721NFT();
    }

    function test_Metadata() public view {
        assertEq(nft.name(), "MyERC721NFT");
        assertEq(nft.symbol(), "MNFT");
    }

    function test_Mint_WithURI() public {
        uint256 tokenId = nft.mint(alice, URI);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.tokenURI(tokenId), URI);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.nextTokenId(), 1);
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

    function test_Mint_ToZeroAddress_Reverts() public {
        vm.expectRevert();
        nft.mint(address(0), URI);
    }
}
