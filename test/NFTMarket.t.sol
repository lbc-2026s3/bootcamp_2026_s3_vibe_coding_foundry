// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC1363Receiver} from "openzeppelin-contracts/contracts/interfaces/IERC1363Receiver.sol";
import {IERC1363Spender} from "openzeppelin-contracts/contracts/interfaces/IERC1363Spender.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
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

    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);

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
        vm.expectEmit(true, true, false, true, address(market));
        emit Listed(tokenId, seller, price);
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
        vm.expectEmit(true, true, true, true, address(market));
        emit Bought(0, buyer, seller, PRICE);
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
        vm.expectEmit(true, true, true, true, address(market));
        emit Bought(0, buyer, seller, PRICE);
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
        vm.expectEmit(true, true, true, true, address(market));
        emit Bought(0, buyer, seller, price);
        market.buyNFT(0, price);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1_000e18 - price);

        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }

    function test_SupportsInterface_ERC1363Hooks() public view {
        assertTrue(market.supportsInterface(type(IERC165).interfaceId));
        assertTrue(market.supportsInterface(type(IERC1363Receiver).interfaceId));
        assertTrue(market.supportsInterface(type(IERC1363Spender).interfaceId));
    }

    function test_Buy_ViaTransferAndCall() public {
        _list(0, PRICE);

        vm.expectEmit(true, true, true, true, address(market));
        emit Bought(0, buyer, seller, PRICE);
        vm.prank(buyer);
        token.transferAndCall(address(market), PRICE, abi.encode(uint256(0)));

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(token.balanceOf(buyer), 1_000e18 - PRICE);
        assertEq(token.balanceOf(address(market)), 0);
    }

    function test_Buy_ViaTransferAndCall_RefundsOverpayment() public {
        _list(0, PRICE);
        uint256 paid = PRICE + 40e18;

        vm.expectEmit(true, true, true, true, address(market));
        emit Bought(0, buyer, seller, PRICE);
        vm.prank(buyer);
        token.transferAndCall(address(market), paid, abi.encode(uint256(0)));

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(token.balanceOf(buyer), 1_000e18 - PRICE);
        assertEq(token.balanceOf(address(market)), 0);
    }

    function test_Buy_ViaApproveAndCall() public {
        _list(0, PRICE);

        vm.expectEmit(true, true, true, true, address(market));
        emit Bought(0, buyer, seller, PRICE);
        vm.prank(buyer);
        token.approveAndCall(address(market), PRICE, abi.encode(uint256(0)));

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(token.balanceOf(buyer), 1_000e18 - PRICE);
        assertEq(token.allowance(buyer, address(market)), 0);
    }

    function test_Buy_ViaTransferFromAndCall() public {
        _list(0, PRICE);
        address operator = makeAddr("operator");

        vm.prank(buyer);
        token.approve(operator, PRICE);

        vm.expectEmit(true, true, true, true, address(market));
        emit Bought(0, buyer, seller, PRICE);
        vm.prank(operator);
        token.transferFromAndCall(buyer, address(market), PRICE, abi.encode(uint256(0)));

        // NFT 与付款归属 token 来源 buyer，而非 operator
        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(token.balanceOf(buyer), 1_000e18 - PRICE);
    }

    function test_RevertWhen_TransferAndCall_InvalidData() public {
        _list(0, PRICE);

        vm.prank(buyer);
        vm.expectRevert();
        token.transferAndCall(address(market), PRICE, bytes("bad"));
    }

    function test_RevertWhen_TransferAndCall_InsufficientPayment() public {
        _list(0, PRICE);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(NFTMarket.InsufficientPayment.selector, PRICE, PRICE - 1));
        token.transferAndCall(address(market), PRICE - 1, abi.encode(uint256(0)));
    }
}
