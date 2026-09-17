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

contract NFTMarketPermitV2Test is Test {
    MyTokenERC2612Permit public token;
    MyERC721UpgradeableNFT public nft;
    NFTMarketPermitV2 public market;

    uint256 public ownerPk = 0xA11CE;
    address public marketOwner = vm.addr(ownerPk);

    uint256 public sellerPk = 0x5E11E4;
    address public seller = vm.addr(sellerPk);

    address public buyer = makeAddr("buyer");
    address public relayer = makeAddr("relayer");
    address public stranger = makeAddr("stranger");

    string constant URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";
    uint256 constant PRICE = 100e18;

    bytes32 internal constant PERMIT_BUY_TYPEHASH =
        keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 internal constant PERMIT_LIST_TYPEHASH =
        keccak256("PermitList(address seller,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)");

    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event PermitListAuthorized(
        address indexed seller, uint256 indexed tokenId, uint256 price, uint256 nonce, uint256 deadline
    );

    function setUp() public {
        token = new MyTokenERC2612Permit();

        MyERC721UpgradeableNFT nftImpl = new MyERC721UpgradeableNFT();
        address nftProxy = UnsafeUpgrades.deployUUPSProxy(
            address(nftImpl), abi.encodeCall(MyERC721UpgradeableNFT.initialize, (marketOwner))
        );
        nft = MyERC721UpgradeableNFT(nftProxy);

        // 先部署 V1 proxy，再升级到 V2（贴近真实升级路径）
        NFTMarketPermitV1 v1Impl = new NFTMarketPermitV1();
        address marketProxy = UnsafeUpgrades.deployUUPSProxy(
            address(v1Impl),
            abi.encodeCall(
                NFTMarketPermitV1.initialize, (IERC20(address(token)), IERC721(address(nft)), marketOwner)
            )
        );

        NFTMarketPermitV2 v2Impl = new NFTMarketPermitV2();
        vm.prank(marketOwner);
        NFTMarketPermitV1(marketProxy).upgradeToAndCall(
            address(v2Impl), abi.encodeCall(NFTMarketPermitV2.initializeV2, ())
        );
        market = NFTMarketPermitV2(marketProxy);

        token.transfer(buyer, 1_000e18);

        vm.prank(marketOwner);
        uint256 tokenId = nft.mint(seller, URI);
        assertEq(tokenId, 0);
    }

    function _signPermitList(address seller_, uint256 tokenId, uint256 price, uint256 nonce, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash = keccak256(abi.encode(PERMIT_LIST_TYPEHASH, seller_, tokenId, price, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", market.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(sellerPk, digest);
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

    function _approveAll() internal {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
    }

    // ─── upgrade / initializeV2 ────────────────────────────────────────

    function test_Upgrade_PreservesV1State() public view {
        assertEq(market.owner(), marketOwner);
        assertEq(address(market.paymentToken()), address(token));
        assertEq(address(market.nft()), address(nft));
        assertEq(nft.ownerOf(0), seller);
        assertEq(market.version(), 2);
    }

    function test_RevertWhen_InitializeV2Twice() public {
        vm.prank(marketOwner);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        market.initializeV2();
    }

    function test_RevertWhen_NonOwnerUpgrade() public {
        NFTMarketPermitV2 another = new NFTMarketPermitV2();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, stranger));
        market.upgradeToAndCall(address(another), "");
    }

    // ─── permitList ────────────────────────────────────────────────────

    function test_PermitList_SellerCanListWithSignature() public {
        _approveAll();
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitList(seller, 0, PRICE, 0, deadline);

        vm.expectEmit(true, true, false, true, address(market));
        emit PermitListAuthorized(seller, 0, PRICE, 0, deadline);
        vm.expectEmit(true, true, false, true, address(market));
        emit Listed(0, seller, PRICE);

        vm.prank(seller);
        market.permitList(seller, 0, PRICE, deadline, v, r, s);

        assertEq(nft.ownerOf(0), address(market));
        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, PRICE);
        assertEq(market.nonces(seller), 1);
    }

    function test_PermitList_RelayerCanSubmit() public {
        _approveAll();
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitList(seller, 0, PRICE, 0, deadline);

        // 任意 relayer 代提交；卖家不发交易
        vm.prank(relayer);
        market.permitList(seller, 0, PRICE, deadline, v, r, s);

        assertEq(nft.ownerOf(0), address(market));
        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, PRICE);
    }

    function test_PermitList_ThenBuyNFT() public {
        _approveAll();
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitList(seller, 0, PRICE, 0, deadline);
        vm.prank(relayer);
        market.permitList(seller, 0, PRICE, deadline, v, r, s);

        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        market.buyNFT(0, PRICE);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
    }

    function test_PermitList_ThenPermitBuy() public {
        _approveAll();
        uint256 deadline = block.timestamp + 1 days;
        (uint8 lv, bytes32 lr, bytes32 ls) = _signPermitList(seller, 0, PRICE, 0, deadline);
        vm.prank(relayer);
        market.permitList(seller, 0, PRICE, deadline, lv, lr, ls);

        (uint8 bv, bytes32 br, bytes32 bs) = _signPermitBuy(buyer, 0, 0, deadline);
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        market.permitBuy(0, PRICE, deadline, bv, br, bs);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), PRICE);
    }

    function test_RevertWhen_PermitListWithoutApproval() public {
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitList(seller, 0, PRICE, 0, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(NFTMarketPermitV2.NotApproved.selector, seller, uint256(0), address(market))
        );
        market.permitList(seller, 0, PRICE, deadline, v, r, s);
    }

    function test_PermitList_WithSingleTokenApprove() public {
        vm.prank(seller);
        nft.approve(address(market), 0);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitList(seller, 0, PRICE, 0, deadline);

        vm.prank(relayer);
        market.permitList(seller, 0, PRICE, deadline, v, r, s);

        assertEq(nft.ownerOf(0), address(market));
        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, PRICE);
    }

    function test_RevertWhen_PermitListExpired() public {
        _approveAll();
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitList(seller, 0, PRICE, 0, deadline);

        vm.warp(deadline + 1);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketPermitV1.SignatureExpired.selector, deadline, block.timestamp));
        market.permitList(seller, 0, PRICE, deadline, v, r, s);
    }

    function test_RevertWhen_PermitListInvalidSigner() public {
        _approveAll();
        uint256 deadline = block.timestamp + 1 days;

        // 用 stranger 的钥签，但声明 seller
        uint256 fakePk = 0xB0B;
        bytes32 structHash = keccak256(abi.encode(PERMIT_LIST_TYPEHASH, seller, uint256(0), PRICE, uint256(0), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", market.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fakePk, digest);

        vm.expectRevert(
            abi.encodeWithSelector(NFTMarketPermitV1.InvalidSigner.selector, vm.addr(fakePk), seller)
        );
        market.permitList(seller, 0, PRICE, deadline, v, r, s);
    }

    function test_RevertWhen_PermitListNonceReuse() public {
        _approveAll();
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitList(seller, 0, PRICE, 0, deadline);

        market.permitList(seller, 0, PRICE, deadline, v, r, s);

        vm.prank(marketOwner);
        uint256 tokenId1 = nft.mint(seller, URI);

        vm.expectRevert();
        market.permitList(seller, tokenId1, PRICE, deadline, v, r, s);
    }

    function test_RevertWhen_PermitListWrongOwner() public {
        _approveAll();
        // NFT 在 seller 手中，却用 stranger 当 seller 参数（且 stranger 没有 NFT）
        uint256 deadline = block.timestamp + 1 days;
        uint256 strangerPk = 0x57A;
        address notOwner = vm.addr(strangerPk);

        bytes32 structHash =
            keccak256(abi.encode(PERMIT_LIST_TYPEHASH, notOwner, uint256(0), PRICE, uint256(0), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", market.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(strangerPk, digest);

        vm.expectRevert(NFTMarketUpgradeable.NotOwner.selector);
        market.permitList(notOwner, 0, PRICE, deadline, v, r, s);
    }

    function test_RevertWhen_PermitListZeroPrice() public {
        _approveAll();
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermitList(seller, 0, 0, 0, deadline);

        vm.expectRevert(NFTMarketUpgradeable.ZeroPrice.selector);
        market.permitList(seller, 0, 0, deadline, v, r, s);
    }

    function test_RevertWhen_PermitListAlreadyListed() public {
        _approveAll();
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v0, bytes32 r0, bytes32 s0) = _signPermitList(seller, 0, PRICE, 0, deadline);
        market.permitList(seller, 0, PRICE, deadline, v0, r0, s0);

        // 已托管在市场；再签一次应 AlreadyListed（且 owner 已不是 seller）
        (uint8 v1, bytes32 r1, bytes32 s1) = _signPermitList(seller, 0, PRICE, 1, deadline);
        vm.expectRevert(NFTMarketUpgradeable.AlreadyListed.selector);
        market.permitList(seller, 0, PRICE, deadline, v1, r1, s1);
    }

    function test_PermitList_SecondListingWithIncrementedNonce() public {
        _approveAll();
        uint256 deadline = block.timestamp + 1 days;

        (uint8 v0, bytes32 r0, bytes32 s0) = _signPermitList(seller, 0, PRICE, 0, deadline);
        market.permitList(seller, 0, PRICE, deadline, v0, r0, s0);

        // 买走后再上架第二枚
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        market.buyNFT(0, PRICE);
        vm.stopPrank();

        vm.prank(marketOwner);
        uint256 tokenId1 = nft.mint(seller, URI);
        (uint8 v1, bytes32 r1, bytes32 s1) = _signPermitList(seller, tokenId1, PRICE, 1, deadline);
        market.permitList(seller, tokenId1, PRICE, deadline, v1, r1, s1);

        assertEq(nft.ownerOf(tokenId1), address(market));
        assertEq(market.nonces(seller), 2);
    }
}
