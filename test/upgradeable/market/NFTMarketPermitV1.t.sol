// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

import {MyTokenERC2612Permit} from "../../../src/MyTokenERC2612Permit.sol";
import {MyERC721UpgradeableNFT} from "../../../src/upgradeable/MyERC721UpgradeableNFT.sol";
import {NFTMarketUpgradeable} from "../../../src/upgradeable/market/NFTMarketUpgradeable.sol";
import {NFTMarketPermitV1} from "../../../src/upgradeable/market/NFTMarketPermitV1.sol";
import {NFTMarketPermitV2} from "../../../src/upgradeable/market/NFTMarketPermitV2.sol";

contract NFTMarketPermitV1Test is Test {
    MyTokenERC2612Permit public token;
    MyERC721UpgradeableNFT public nft;
    NFTMarketPermitV1 public market;
    NFTMarketPermitV1 public implementation;

    uint256 public ownerPk = 0xA11CE;
    address public marketOwner = vm.addr(ownerPk);

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    address public stranger = makeAddr("stranger");
    address public alice = makeAddr("alice");

    string constant URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";
    uint256 constant PRICE = 100e18;

    bytes32 internal constant PERMIT_BUY_TYPEHASH =
        keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 nonce,uint256 deadline)");

    event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event PermitBuyAuthorized(address indexed buyer, uint256 indexed tokenId, uint256 nonce, uint256 deadline);

    function setUp() public {
        token = new MyTokenERC2612Permit();

        MyERC721UpgradeableNFT nftImpl = new MyERC721UpgradeableNFT();
        address nftProxy = UnsafeUpgrades.deployUUPSProxy(
            address(nftImpl), abi.encodeCall(MyERC721UpgradeableNFT.initialize, (marketOwner))
        );
        nft = MyERC721UpgradeableNFT(nftProxy);

        implementation = new NFTMarketPermitV1();
        market = _wrap(address(implementation), IERC20(address(token)), IERC721(address(nft)), marketOwner);

        token.transfer(buyer, 1_000e18);
        token.transfer(stranger, 1_000e18);

        vm.prank(marketOwner);
        uint256 tokenId = nft.mint(seller, URI);
        assertEq(tokenId, 0);
    }

    function _wrap(address impl, IERC20 paymentToken_, IERC721 nft_, address initialOwner)
        internal
        returns (NFTMarketPermitV1)
    {
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            impl, abi.encodeCall(NFTMarketPermitV1.initialize, (paymentToken_, nft_, initialOwner))
        );
        return NFTMarketPermitV1(proxy);
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

    // ─── initialize / UUPS ─────────────────────────────────────────────

    function test_Initialize_SetsOwnerAndTokenNft() public view {
        assertEq(market.owner(), marketOwner);
        assertEq(address(market.paymentToken()), address(token));
        assertEq(address(market.nft()), address(nft));
        assertEq(market.nonces(buyer), 0);
    }

    function test_RevertWhen_InitializeTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        market.initialize(IERC20(address(token)), IERC721(address(nft)), marketOwner);
    }

    function test_RevertWhen_InitializeImplementation() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(IERC20(address(token)), IERC721(address(nft)), marketOwner);
    }

    function test_RevertWhen_InitializeZeroPaymentToken() public {
        NFTMarketPermitV1 impl = new NFTMarketPermitV1();
        vm.expectRevert(NFTMarketUpgradeable.ZeroAddress.selector);
        UnsafeUpgrades.deployUUPSProxy(
            address(impl),
            abi.encodeCall(NFTMarketPermitV1.initialize, (IERC20(address(0)), IERC721(address(nft)), marketOwner))
        );
    }

    function test_RevertWhen_InitializeZeroNft() public {
        NFTMarketPermitV1 impl = new NFTMarketPermitV1();
        vm.expectRevert(NFTMarketUpgradeable.ZeroAddress.selector);
        UnsafeUpgrades.deployUUPSProxy(
            address(impl),
            abi.encodeCall(NFTMarketPermitV1.initialize, (IERC20(address(token)), IERC721(address(0)), marketOwner))
        );
    }

    function test_RevertWhen_NonOwnerUpgrade() public {
        NFTMarketPermitV2 v2 = new NFTMarketPermitV2();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        market.upgradeToAndCall(address(v2), "");
    }

    function test_Upgrade_PreservesListingsAndPermitBuy() public {
        _list(0, PRICE);

        NFTMarketPermitV2 v2 = new NFTMarketPermitV2();
        vm.prank(marketOwner);
        market.upgradeToAndCall(address(v2), abi.encodeCall(NFTMarketPermitV2.initializeV2, ()));

        NFTMarketPermitV2 upgraded = NFTMarketPermitV2(address(market));
        assertEq(upgraded.version(), 2);
        assertEq(upgraded.owner(), marketOwner);
        assertEq(address(upgraded.paymentToken()), address(token));
        (address listedSeller, uint256 listedPrice) = upgraded.listings(0);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, PRICE);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(buyer, 0, 0, deadline);

        vm.startPrank(buyer);
        token.approve(address(upgraded), PRICE);
        upgraded.permitBuy(0, PRICE, deadline, v, r, s);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(upgraded.nonces(buyer), 1);
    }

    // ─── list / buyNFT ─────────────────────────────────────────────────

    function test_BuyNFT_StillWorksWithoutPermit() public {
        _list(0, PRICE);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        market.buyNFT(0, PRICE);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
    }

    function test_RevertWhen_ListZeroPrice() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        vm.expectRevert(NFTMarketUpgradeable.ZeroPrice.selector);
        market.list(0, 0);
        vm.stopPrank();
    }

    function test_RevertWhen_BuyInsufficientPayment() public {
        _list(0, PRICE);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketUpgradeable.InsufficientPayment.selector, PRICE, PRICE - 1));
        market.buyNFT(0, PRICE - 1);
        vm.stopPrank();
    }

    // ─── permitBuy ─────────────────────────────────────────────────────

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

        uint256 fakePk = 0xB0B;
        bytes32 structHash = keccak256(abi.encode(PERMIT_BUY_TYPEHASH, buyer, uint256(0), uint256(0), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", market.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fakePk, digest);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        vm.expectRevert(
            abi.encodeWithSelector(NFTMarketPermitV1.InvalidSigner.selector, vm.addr(fakePk), marketOwner)
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
        vm.expectRevert(abi.encodeWithSelector(NFTMarketPermitV1.SignatureExpired.selector, deadline, block.timestamp));
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

        vm.prank(marketOwner);
        uint256 tokenId1 = nft.mint(seller, URI);
        _list(tokenId1, PRICE);

        vm.startPrank(buyer);
        vm.expectRevert();
        market.permitBuy(tokenId1, PRICE, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuy_StrangerCannotUseBuyersSignature() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitBuy(buyer, 0, 0, deadline);

        vm.startPrank(stranger);
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

        vm.prank(marketOwner);
        uint256 tokenId1 = nft.mint(seller, URI);
        _list(tokenId1, PRICE);
        (uint8 v1, bytes32 r1, bytes32 s1) = _signPermitBuy(buyer, tokenId1, 1, deadline);

        vm.prank(buyer);
        market.permitBuy(tokenId1, PRICE, deadline, v1, r1, s1);

        assertEq(nft.ownerOf(0), buyer);
        assertEq(nft.ownerOf(tokenId1), buyer);
        assertEq(market.nonces(buyer), 2);
    }
}
