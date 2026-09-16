// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import {MyTokenERC2612Permit} from "../src/MyTokenERC2612Permit.sol";
import {MyERC721NFT} from "../src/MyERC721NFT.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {AirdopMerkleNFTMarket} from "../src/AirdopMerkleNFTMarket.sol";
import {MerkleWhitelist} from "../src/libraries/MerkleWhitelist.sol";

contract AirdopMerkleNFTMarketTest is Test {
    MyTokenERC2612Permit public token;
    MyERC721NFT public nft;
    AirdopMerkleNFTMarket public market;

    uint256 public ownerPk = 0xA11CE;
    address public marketOwner = vm.addr(ownerPk);

    address public seller = makeAddr("seller");
    address public stranger = makeAddr("stranger");

    /// @dev 默认测 8 人名单；改这个数即可，不必改数组类型
    uint256 internal constant WHITELIST_SIZE = 8;
    // wlPk：私钥（给 token.permit 签名）；whitelist：对应地址，setUp 里按 WHITELIST_SIZE 生成
    uint256[] public wlPk;
    address[] public whitelist;

    string constant URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";
    uint256 constant PRICE = 100e18;
    uint256 constant DISCOUNTED = 50e18; // 折扣

    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event PermitPrePaid(address indexed owner, uint256 value, uint256 deadline);
    event NFTClaimed(address indexed account, uint256 indexed tokenId, uint256 paid);

    function setUp() public {
        uint256 n = WHITELIST_SIZE;
        whitelist = new address[](n);
        wlPk = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            (address addr, uint256 pk) = makeAddrAndKey(string.concat("wl", vm.toString(i)));
            whitelist[i] = addr;
            wlPk[i] = pk;
        }

        token = new MyTokenERC2612Permit();
        nft = new MyERC721NFT();
        market = new AirdopMerkleNFTMarket(token, nft, marketOwner, MerkleWhitelist.root(whitelist));

        for (uint256 i = 0; i < n; ++i) {
            token.transfer(whitelist[i], 1_000e18);
        }
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

    function _proof(uint256 index) internal view returns (bytes32[] memory) {
        return MerkleWhitelist.proof(whitelist, index);
    }

    function _signTokenPermit(uint256 ownerPk_, address owner, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(market), value, token.nonces(owner), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(ownerPk_, digest);
    }

    function test_Constructor_StoresMerkleRootAndImmutables() public view {
        assertEq(market.owner(), marketOwner);
        assertEq(address(market.paymentToken()), address(token));
        assertEq(address(market.nft()), address(nft));
        assertEq(market.merkleRoot(), MerkleWhitelist.root(whitelist));
        assertEq(market.WHITELIST_PRICE_BPS(), 5_000);
        assertEq(market.whitelistLeaf(whitelist[0]), MerkleWhitelist.leaf(whitelist[0]));
    }

    function test_Constructor_ZeroMerkleRoot_Reverts() public {
        vm.expectRevert(AirdopMerkleNFTMarket.ZeroMerkleRoot.selector);
        new AirdopMerkleNFTMarket(token, nft, marketOwner, bytes32(0));
    }

    function test_PermitPrePay_InvalidSignature_Reverts() public {
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signTokenPermit(wlPk[0], whitelist[0], DISCOUNTED, deadline);

        // whitelist[0] 的 permit 签名不能拿来给 whitelist[1] 授权使用
        vm.prank(whitelist[1]);
        vm.expectRevert(AirdopMerkleNFTMarket.PermitFailed.selector);
        market.permitPrePay(DISCOUNTED, deadline, v, r, s);
    }

    function test_PermitPrePay_SetsAllowance() public {
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signTokenPermit(wlPk[0], whitelist[0], DISCOUNTED, deadline);

        vm.expectEmit(true, false, false, true, address(market));
        emit PermitPrePaid(whitelist[0], DISCOUNTED, deadline);

        vm.prank(whitelist[0]);
        market.permitPrePay(DISCOUNTED, deadline, v, r, s);

        assertEq(token.allowance(whitelist[0], address(market)), DISCOUNTED);
        assertEq(token.nonces(whitelist[0]), 1);
    }

    function test_ClaimNFT_WhitelistedBuyerPaysHalfPrice() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signTokenPermit(wlPk[3], whitelist[3], DISCOUNTED, deadline);
        bytes32[] memory proof = _proof(3);

        vm.startPrank(whitelist[3]);
        market.permitPrePay(DISCOUNTED, deadline, v, r, s);

        vm.expectEmit(true, true, true, true, address(market));
        emit Bought(0, whitelist[3], seller, DISCOUNTED);
        vm.expectEmit(true, true, false, true, address(market));
        emit NFTClaimed(whitelist[3], 0, DISCOUNTED);
        market.claimNFT(0, proof);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), whitelist[3]);
        assertEq(token.balanceOf(seller), DISCOUNTED);
        assertEq(token.balanceOf(whitelist[3]), 1_000e18 - DISCOUNTED);
        assertTrue(market.hasClaimed(whitelist[3]));
        (address listedSeller, uint256 listedPrice) = market.listings(0);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }

    function test_Multicall_PermitPrePayAndClaimNFT() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signTokenPermit(wlPk[1], whitelist[1], DISCOUNTED, deadline);
        bytes32[] memory proof = _proof(1);

        // 数组长度2，每个元素都是变长数组，分别是 permitPrePay 和 claimNFT 的参数
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(market.permitPrePay, (DISCOUNTED, deadline, v, r, s));
        calls[1] = abi.encodeCall(market.claimNFT, (uint256(0), proof));

        vm.prank(whitelist[1]);
        market.multicall(calls);

        assertEq(nft.ownerOf(0), whitelist[1]);
        assertEq(token.balanceOf(seller), DISCOUNTED);
        assertEq(token.balanceOf(whitelist[1]), 1_000e18 - DISCOUNTED);
        assertTrue(market.hasClaimed(whitelist[1]));
        // 授权已经用完了
        assertEq(token.allowance(whitelist[1], address(market)), 0);
    }

    function test_ClaimNFT_AllWhitelistAddresses() public {
        uint256 n = whitelist.length;
        for (uint256 i = 0; i < n; ++i) {
            uint256 tokenId = i == 0 ? 0 : nft.mint(seller, URI);
            _list(tokenId, PRICE);

            uint256 deadline = block.timestamp + 1 days;
            (uint8 v, bytes32 r, bytes32 s) = _signTokenPermit(wlPk[i], whitelist[i], DISCOUNTED, deadline);
            bytes32[] memory proof = _proof(i);

            bytes[] memory calls = new bytes[](2);
            calls[0] = abi.encodeCall(market.permitPrePay, (DISCOUNTED, deadline, v, r, s));
            calls[1] = abi.encodeCall(market.claimNFT, (tokenId, proof));

            vm.prank(whitelist[i]);
            market.multicall(calls);

            assertEq(nft.ownerOf(tokenId), whitelist[i]);
            assertTrue(market.hasClaimed(whitelist[i]));
            assertEq(token.allowance(whitelist[i], address(market)), 0);
            assertEq(token.balanceOf(whitelist[i]), 1_000e18 - DISCOUNTED);
            assertEq(token.balanceOf(seller), DISCOUNTED * (i + 1));
        }

        assertEq(token.balanceOf(seller), DISCOUNTED * n);
    }

    function test_ClaimNFT_StrangerReverts() public {
        _list(0, PRICE);
        bytes32[] memory proof = _proof(0);

        vm.startPrank(stranger);
        token.approve(address(market), DISCOUNTED);
        vm.expectRevert(abi.encodeWithSelector(AirdopMerkleNFTMarket.NotWhitelisted.selector, stranger));
        market.claimNFT(0, proof);
        vm.stopPrank();
    }

    function test_ClaimNFT_WrongProofReverts() public {
        _list(0, PRICE);
        // index 0 的 proof 不能给 index 2 用
        bytes32[] memory proof = _proof(0);

        vm.startPrank(whitelist[2]);
        token.approve(address(market), DISCOUNTED);
        vm.expectRevert(abi.encodeWithSelector(AirdopMerkleNFTMarket.NotWhitelisted.selector, whitelist[2]));
        market.claimNFT(0, proof);
        vm.stopPrank();
    }

    function test_ClaimNFT_EmptyProofReverts() public {
        _list(0, PRICE);
        bytes32[] memory proof = new bytes32[](0);

        vm.startPrank(whitelist[0]);
        token.approve(address(market), DISCOUNTED);
        vm.expectRevert(abi.encodeWithSelector(AirdopMerkleNFTMarket.NotWhitelisted.selector, whitelist[0]));
        market.claimNFT(0, proof);
        vm.stopPrank();
    }

    function test_ClaimNFT_AlreadyClaimedReverts() public {
        _list(0, PRICE);
        bytes32[] memory proof = _proof(0);

        vm.startPrank(whitelist[0]);
        token.approve(address(market), DISCOUNTED * 2);
        market.claimNFT(0, proof);
        vm.stopPrank();

        uint256 tokenId1 = nft.mint(seller, URI);
        _list(tokenId1, PRICE);

        vm.startPrank(whitelist[0]);
        vm.expectRevert(abi.encodeWithSelector(AirdopMerkleNFTMarket.AlreadyClaimed.selector, whitelist[0]));
        market.claimNFT(tokenId1, proof);
        vm.stopPrank();
    }

    function test_ClaimNFT_NotListedReverts() public {
        bytes32[] memory proof = _proof(0);

        vm.startPrank(whitelist[0]);
        token.approve(address(market), DISCOUNTED);
        vm.expectRevert(NFTMarket.NotListed.selector);
        market.claimNFT(0, proof);
        vm.stopPrank();
    }

    function test_ClaimNFT_PriceOne_RevertsZeroDiscount() public {
        _list(0, 1);
        bytes32[] memory proof = _proof(0);

        vm.startPrank(whitelist[0]);
        token.approve(address(market), 1);
        vm.expectRevert(NFTMarket.ZeroPrice.selector);
        market.claimNFT(0, proof);
        vm.stopPrank();
    }

    function test_ClaimNFT_WithoutAllowanceReverts() public {
        _list(0, PRICE);
        bytes32[] memory proof = _proof(0);

        vm.prank(whitelist[0]);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(market), uint256(0), DISCOUNTED)
        );
        market.claimNFT(0, proof);

        assertFalse(market.hasClaimed(whitelist[0]));
        (, uint256 listedPrice) = market.listings(0);
        assertEq(listedPrice, PRICE);
    }

    function test_PermitPrePay_FrontrunStillAllowsClaim() public {
        _list(0, PRICE);
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signTokenPermit(wlPk[4], whitelist[4], DISCOUNTED, deadline);
        bytes32[] memory proof = _proof(4);

        // 他人抢先提交同一笔 permit
        token.permit(whitelist[4], address(market), DISCOUNTED, deadline, v, r, s);
        assertEq(token.allowance(whitelist[4], address(market)), DISCOUNTED);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(market.permitPrePay, (DISCOUNTED, deadline, v, r, s));
        calls[1] = abi.encodeCall(market.claimNFT, (uint256(0), proof));

        vm.prank(whitelist[4]);
        market.multicall(calls);

        assertEq(nft.ownerOf(0), whitelist[4]);
    }

    function test_PermitPrePay_Expired_Reverts() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signTokenPermit(wlPk[0], whitelist[0], DISCOUNTED, deadline);

        vm.warp(deadline + 1);
        vm.prank(whitelist[0]);
        vm.expectRevert(AirdopMerkleNFTMarket.PermitFailed.selector);
        market.permitPrePay(DISCOUNTED, deadline, v, r, s);
    }

    function test_ClaimNFT_SecondWhitelistLosesSameListingThenClaimsAnother() public {
        _list(0, PRICE);
        bytes32[] memory proof0 = _proof(0);
        bytes32[] memory proof1 = _proof(1);

        vm.startPrank(whitelist[0]);
        token.approve(address(market), DISCOUNTED);
        market.claimNFT(0, proof0);
        vm.stopPrank();

        vm.startPrank(whitelist[1]);
        token.approve(address(market), DISCOUNTED);
        vm.expectRevert(NFTMarket.NotListed.selector);
        market.claimNFT(0, proof1);
        vm.stopPrank();

        assertFalse(market.hasClaimed(whitelist[1]));

        uint256 tokenId1 = nft.mint(seller, URI);
        _list(tokenId1, PRICE);

        vm.prank(whitelist[1]);
        market.claimNFT(tokenId1, proof1);

        assertEq(nft.ownerOf(0), whitelist[0]);
        assertEq(nft.ownerOf(tokenId1), whitelist[1]);
        assertTrue(market.hasClaimed(whitelist[1]));
    }

    function test_BuyNFT_StillWorksAtFullPrice() public {
        _list(0, PRICE);

        vm.startPrank(stranger);
        token.approve(address(market), PRICE);
        market.buyNFT(0, PRICE);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), stranger);
        assertEq(token.balanceOf(seller), PRICE);
        assertFalse(market.hasClaimed(stranger));
    }

    function test_ClaimNFT_OddPriceRoundsDown() public {
        uint256 oddPrice = 101;
        uint256 paid = (oddPrice * 5_000) / 10_000;
        assertEq(paid, 50);

        _list(0, oddPrice);
        bytes32[] memory proof = _proof(5);

        vm.startPrank(whitelist[5]);
        token.approve(address(market), paid);
        market.claimNFT(0, proof);
        vm.stopPrank();

        assertEq(token.balanceOf(seller), paid);
        assertEq(nft.ownerOf(0), whitelist[5]);
    }

    function testFuzz_ClaimNFT_WhitelistIndex(uint256 index) public {
        index = bound(index, 0, whitelist.length - 1);
        _list(0, PRICE);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signTokenPermit(wlPk[index], whitelist[index], DISCOUNTED, deadline);
        bytes32[] memory proof = _proof(index);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(market.permitPrePay, (DISCOUNTED, deadline, v, r, s));
        calls[1] = abi.encodeCall(market.claimNFT, (uint256(0), proof));

        vm.prank(whitelist[index]);
        market.multicall(calls);

        assertEq(nft.ownerOf(0), whitelist[index]);
        assertEq(token.balanceOf(seller), DISCOUNTED);
        assertTrue(market.hasClaimed(whitelist[index]));
    }

    function test_ClaimNFT_TwelveAddressWhitelist() public {
        uint256 n = 12;
        address[] memory accounts = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            (address addr,) = makeAddrAndKey(string.concat("wl12-", vm.toString(i)));
            accounts[i] = addr;
            token.transfer(addr, 1_000e18);
        }

        AirdopMerkleNFTMarket market12 =
            new AirdopMerkleNFTMarket(token, nft, marketOwner, MerkleWhitelist.root(accounts));

        uint256 tokenId = nft.mint(seller, URI);
        vm.startPrank(seller);
        nft.approve(address(market12), tokenId);
        market12.list(tokenId, PRICE);
        vm.stopPrank();

        uint256 pick = 11;
        bytes32[] memory proof = MerkleWhitelist.proof(accounts, pick);
        assertEq(proof.length, 4); // 12 pad 到 16，proof 深度 4

        vm.startPrank(accounts[pick]);
        token.approve(address(market12), DISCOUNTED);
        market12.claimNFT(tokenId, proof);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), accounts[pick]);
        assertTrue(market12.hasClaimed(accounts[pick]));
    }

    function testFuzz_MerkleWhitelist_ProofVerifies(uint256 n, uint256 index) public pure {
        n = bound(n, 1, 24);
        index = bound(index, 0, n - 1);

        address[] memory accounts = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            accounts[i] = address(uint160(uint256(keccak256(abi.encode(n, i, uint256(1))))));
        }

        bytes32 root_ = MerkleWhitelist.root(accounts);
        bytes32[] memory proof = MerkleWhitelist.proof(accounts, index);
        assertTrue(MerkleProof.verify(proof, root_, MerkleWhitelist.leaf(accounts[index])));
    }

    function test_MerkleWhitelist_Empty_Reverts() public {
        address[] memory empty = new address[](0);
        vm.expectRevert(MerkleWhitelist.EmptyWhitelist.selector);
        this.rootExternal(empty);
    }

    function test_MerkleWhitelist_IndexOutOfBounds_Reverts() public {
        uint256 n = whitelist.length;
        vm.expectRevert(abi.encodeWithSelector(MerkleWhitelist.IndexOutOfBounds.selector, n, n));
        this.proofExternal(whitelist, n);
    }

    function rootExternal(address[] calldata accounts) external pure returns (bytes32) {
        return MerkleWhitelist.root(accounts);
    }

    function proofExternal(address[] calldata accounts, uint256 index) external pure returns (bytes32[] memory) {
        return MerkleWhitelist.proof(accounts, index);
    }
}
