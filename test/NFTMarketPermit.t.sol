// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyTokenERC1363} from "../src/MyTokenERC1363.sol";
import {MyERC721NFT} from "../src/MyERC721NFT.sol";
import {NFTMarketPermit} from "../src/NFTMarketPermit.sol";

contract NFTMarketPermitTest is Test {
    MyTokenERC1363 public token;
    MyERC721NFT public nft;
    NFTMarketPermit public market;

    uint256 public ownerPk = 0xA11CE;
    address public marketOwner = vm.addr(ownerPk);

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    address public stranger = makeAddr("stranger");

    string constant URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";
    uint256 constant PRICE = 100e18;

    bytes32 internal constant PERMIT_BUY_TYPEHASH =
        keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 nonce,uint256 deadline)");

    event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event PermitBuyAuthorized(address indexed buyer, uint256 indexed tokenId, uint256 nonce, uint256 deadline);

    function setUp() public {
        token = new MyTokenERC1363();
        nft = new MyERC721NFT();
        market = new NFTMarketPermit(token, nft, marketOwner);

        token.transfer(buyer, 1_000e18);
        token.transfer(stranger, 1_000e18);

        uint256 tokenId = nft.mint(seller, URI);
        assertEq(tokenId, 0);
    }

    function _list(uint256 tokenId, uint256 price) internal {
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();
    }

    function _signPermitBuy(address buyer_, uint256 tokenId, uint256 nonce, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash = keccak256(abi.encode(PERMIT_BUY_TYPEHASH, buyer_, tokenId, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", market.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(ownerPk, digest);
    }

    function test_Constructor_SetsOwnerAndImmutables() public view {
        assertEq(market.owner(), marketOwner);
        assertEq(address(market.paymentToken()), address(token));
        assertEq(address(market.nft()), address(nft));
        assertEq(market.nonces(buyer), 0);
    }

    function test_PermitBuy_WhitelistedBuyerCanPurchase() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(buyer, 0, 0, deadline);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        vm.expectEmit(true, true, false, true, address(market));
        emit PermitBuyAuthorized(buyer, 0, 0, deadline);
        vm.expectEmit(true, true, true, true, address(market));
        emit Bought(0, buyer, seller, PRICE);
        market.permitBuy(0, PRICE, deadline, v, r, s);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(market.nonces(buyer), 1);
        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }

    function test_PermitBuy_RevertsWithoutValidOwnerSignature() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 days;

        // 用买家自己的钥签，不应通过
        uint256 fakePk = 0xB0B;
        bytes32 structHash = keccak256(abi.encode(PERMIT_BUY_TYPEHASH, buyer, uint256(0), uint256(0), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", market.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fakePk, digest);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        vm.expectRevert(
            abi.encodeWithSelector(NFTMarketPermit.InvalidSigner.selector, vm.addr(fakePk), marketOwner)
        );
        market.permitBuy(0, PRICE, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuy_RevertsWhenExpired() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(buyer, 0, 0, deadline);

        vm.warp(deadline + 1);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketPermit.SignatureExpired.selector, deadline, block.timestamp));
        market.permitBuy(0, PRICE, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuy_RevertsOnNonceReuse() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(buyer, 0, 0, deadline);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE * 2);
        market.permitBuy(0, PRICE, deadline, v, r, s);
        vm.stopPrank();

        // 再铸并上架一个 NFT，用同一签名（nonce=0）应失败
        uint256 tokenId1 = nft.mint(seller, URI);
        _list(tokenId1, PRICE);

        vm.startPrank(buyer);
        vm.expectRevert(); // InvalidSigner（digest 对应 nonce 已变）
        market.permitBuy(tokenId1, PRICE, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuy_StrangerCannotUseBuyersSignature() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(buyer, 0, 0, deadline);

        vm.startPrank(stranger);
        token.approve(address(market), PRICE);
        // digest 绑定 buyer，stranger 调用会恢复出不同 signer
        vm.expectRevert();
        market.permitBuy(0, PRICE, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuy_RevertsOnWrongTokenId() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 days;
        // 签名授权 tokenId=1，实际上架的是 0
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(buyer, 1, 0, deadline);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        vm.expectRevert();
        market.permitBuy(0, PRICE, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuy_SecondPurchaseWithIncrementedNonce() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 days;

        (uint8 v0, bytes32 r0, bytes32 s0) = _signPermitBuy(buyer, 0, 0, deadline);
        vm.startPrank(buyer);
        token.approve(address(market), PRICE * 2);
        market.permitBuy(0, PRICE, deadline, v0, r0, s0);
        vm.stopPrank();

        uint256 tokenId1 = nft.mint(seller, URI);
        _list(tokenId1, PRICE);
        (uint8 v1, bytes32 r1, bytes32 s1) = _signPermitBuy(buyer, tokenId1, 1, deadline);

        vm.prank(buyer);
        market.permitBuy(tokenId1, PRICE, deadline, v1, r1, s1);

        assertEq(nft.ownerOf(0), buyer);
        assertEq(nft.ownerOf(tokenId1), buyer);
        assertEq(market.nonces(buyer), 2);
    }

    function test_BuyNFT_StillWorksWithoutPermit() public {
        _list(0, PRICE);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        market.buyNFT(0, PRICE);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
    }
}
