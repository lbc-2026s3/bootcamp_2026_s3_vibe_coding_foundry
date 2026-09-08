// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyTokenERC1363} from "../src/MyTokenERC1363.sol";
import {MyERC721NFT} from "../src/MyERC721NFT.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

contract NFTMarketTest is Test {
    MyTokenERC1363 public token;
    MyERC721NFT public nft;
    NFTMarket public market;

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");

    string constant URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";
    uint256 constant PRICE = 100e18;

    function setUp() public {
        token = new MyTokenERC1363();
        nft = new MyERC721NFT();
        market = new NFTMarket(token, nft);

        token.transfer(buyer, 1_000e18);

        uint256 tokenId = nft.mint(seller, URI);
        assertEq(tokenId, 0);
    }

    function _list(uint256 tokenId, uint256 price) internal {
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();
    }

    function test_List_EscrowsNftAndStoresPrice() public {
        _list(0, PRICE);

        assertEq(nft.ownerOf(0), address(market));
        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, PRICE);
    }

    function test_BuyNFT_TransfersTokenAndNft() public {
        _list(0, PRICE);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        market.buyNFT(0, PRICE);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(token.balanceOf(buyer), 1_000e18 - PRICE);

        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }

    function test_BuyNFT_AllowsOverpayment_ChargesListedPrice() public {
        _list(0, PRICE);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE + 50e18);
        market.buyNFT(0, PRICE + 50e18);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(token.balanceOf(buyer), 1_000e18 - PRICE);
    }

    function test_RevertWhen_ListZeroPrice() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        vm.expectRevert(NFTMarket.ZeroPrice.selector);
        market.list(0, 0);
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerLists() public {
        vm.prank(buyer);
        vm.expectRevert(NFTMarket.NotOwner.selector);
        market.list(0, PRICE);
    }

    function test_RevertWhen_BuyNotListed() public {
        vm.prank(buyer);
        vm.expectRevert(NFTMarket.NotListed.selector);
        market.buyNFT(0, PRICE);
    }

    function test_RevertWhen_InsufficientPayment() public {
        _list(0, PRICE);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        vm.expectRevert(abi.encodeWithSelector(NFTMarket.InsufficientPayment.selector, PRICE, PRICE - 1));
        market.buyNFT(0, PRICE - 1);
        vm.stopPrank();
    }

    function test_RevertWhen_DoubleList() public {
        _list(0, PRICE);

        vm.prank(seller);
        vm.expectRevert(NFTMarket.AlreadyListed.selector);
        market.list(0, PRICE);
    }

    function testFuzz_BuyNFT_Roundtrip(uint256 price) public {
        price = bound(price, 1, 1_000e18);

        _list(0, price);

        vm.startPrank(buyer);
        token.approve(address(market), price);
        market.buyNFT(0, price);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1_000e18 - price);

        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }
}
