// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {ArtNFT} from "../../src/nft/ArtNFT.sol";

contract NFTReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @dev 成交收款时去买另一件仍在售的作品。外层 `nonReentrant` 必须让这次购买失败。
contract ReenteringSeller is IERC721Receiver {
    ArtNFT public immutable nft;
    uint256 public attacks;
    uint256 public targetId;

    constructor(ArtNFT nft_) {
        nft = nft_;
    }

    function setTarget(uint256 tokenId) external {
        targetId = tokenId;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
        attacks += 1;
        if (attacks == 1) {
            try nft.buyArtwork{value: msg.value}(targetId) {} catch {}
        }
    }
}

/// @dev 提取版税时再提取一次，确认同一笔版税不会付出两次。
contract ReenteringArtist is IERC721Receiver {
    ArtNFT public immutable nft;
    uint256 public attacks;
    bool public armed;

    constructor(ArtNFT nft_) {
        nft = nft_;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function arm() external {
        armed = true;
    }

    function withdraw() external {
        nft.withdrawRoyalties();
    }

    receive() external payable {
        if (!armed) return;
        attacks += 1;
        armed = false;
        try nft.withdrawRoyalties() {} catch {}
    }
}

/// @dev 铸造回调里把刚铸出的 token 转给别人。挂单不能跟着到新持有人身上。
contract MintAndPush is IERC721Receiver {
    ArtNFT public immutable nft;
    address public immutable recipient;

    constructor(ArtNFT nft_, address recipient_) {
        nft = nft_;
        recipient = recipient_;
    }

    function mint() external returns (uint256 tokenId) {
        tokenId = nft.createArtwork("Blue", "Ada", 1 ether, 500, "ipfs://blue");
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external returns (bytes4) {
        nft.transferFrom(address(this), recipient, tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract RejectEther is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
        revert("no eth");
    }
}

contract ArtNFTTest is Test {
    ArtNFT internal nft;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal constant PRICE = 1 ether;
    uint256 internal constant ROYALTY_BPS = 500; // 5%

    event ArtworkCreated(uint256 indexed tokenId, string title, string artist, uint256 price);
    event ArtworkSold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event RoyaltyAccrued(uint256 indexed tokenId, address indexed artist, uint256 amount);
    event RoyaltyPaid(address indexed artist, uint256 amount);

    function setUp() public {
        nft = new ArtNFT();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
    }

    function test_CreateArtwork_MintsListedTokenAndRecordsRoyalty() public {
        vm.expectEmit(true, false, false, true, address(nft));
        emit ArtworkCreated(0, "Blue", "Ada", PRICE);

        vm.prank(alice);
        uint256 tokenId = nft.createArtwork("Blue", "Ada", PRICE, ROYALTY_BPS, "ipfs://blue");

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.totalArtworks(), 1);
        assertEq(nft.tokenURI(tokenId), "ipfs://blue");

        (
            string memory title,
            string memory artist,
            uint256 price,
            bool forSale,
            uint256 royaltyPercentage,
            address creator
        ) = nft.artworks(tokenId);
        assertEq(title, "Blue");
        assertEq(artist, "Ada");
        assertEq(price, PRICE);
        assertTrue(forSale);
        assertEq(royaltyPercentage, ROYALTY_BPS);
        assertEq(creator, alice);

        uint256[] memory created = nft.getArtistArtworks(alice);
        assertEq(created.length, 1);
        assertEq(created[0], tokenId);

        (address receiver, uint256 royalty) = nft.royaltyInfo(tokenId, PRICE);
        assertEq(receiver, alice);
        assertEq(royalty, (PRICE * ROYALTY_BPS) / nft.ROYALTY_DENOMINATOR());
        assertTrue(nft.supportsInterface(type(IERC2981).interfaceId));
    }

    function test_CreateArtwork_AssignsSequentialIds() public {
        vm.startPrank(alice);
        assertEq(nft.createArtwork("Blue", "Ada", PRICE, ROYALTY_BPS, "ipfs://blue"), 0);
        assertEq(nft.createArtwork("Red", "Ada", PRICE, 0, "ipfs://red"), 1);
        vm.stopPrank();

        uint256[] memory created = nft.getArtistArtworks(alice);
        assertEq(created.length, 2);
        assertEq(created[1], 1);
    }

    function test_RevertWhen_RoyaltyTooHigh() public {
        uint256 tooHigh = nft.MAX_ROYALTY() + 1;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ArtNFT.RoyaltyTooHigh.selector, tooHigh, nft.MAX_ROYALTY()));
        nft.createArtwork("Blue", "Ada", PRICE, tooHigh, "ipfs://blue");
    }

    function test_RevertWhen_MetadataEmptyOrPriceZero() public {
        vm.startPrank(alice);
        vm.expectRevert(ArtNFT.EmptyMetadata.selector);
        nft.createArtwork("", "Ada", PRICE, ROYALTY_BPS, "ipfs://blue");
        vm.expectRevert(ArtNFT.InvalidPrice.selector);
        nft.createArtwork("Blue", "Ada", 0, ROYALTY_BPS, "ipfs://blue");
        vm.stopPrank();
    }

    function test_BuyArtwork_PrimarySalePaysSellerFullPrice() public {
        uint256 tokenId = _mint(alice);

        uint256 sellerBefore = alice.balance;
        uint256 buyerBefore = bob.balance;

        vm.expectEmit(true, true, false, true, address(nft));
        emit ArtworkSold(tokenId, bob, PRICE);

        vm.prank(bob);
        nft.buyArtwork{value: PRICE}(tokenId);

        assertEq(nft.ownerOf(tokenId), bob);
        assertFalse(_forSale(tokenId));
        assertEq(alice.balance, sellerBefore + PRICE);
        assertEq(bob.balance, buyerBefore - PRICE);
        assertEq(nft.artistRoyalties(alice), 0);
        assertEq(address(nft).balance, 0);
    }

    function test_BuyArtwork_RefundsOverpayment() public {
        uint256 tokenId = _mint(alice);
        uint256 buyerBefore = bob.balance;

        vm.prank(bob);
        nft.buyArtwork{value: PRICE + 0.4 ether}(tokenId);

        assertEq(bob.balance, buyerBefore - PRICE);
        assertEq(address(nft).balance, 0);
    }

    function test_BuyArtwork_SecondarySaleAccruesRoyaltyOnce() public {
        uint256 tokenId = _mint(alice);

        vm.prank(bob);
        nft.buyArtwork{value: PRICE}(tokenId);

        vm.prank(bob);
        nft.toggleForSale(tokenId);

        uint256 royalty = (PRICE * ROYALTY_BPS) / nft.ROYALTY_DENOMINATOR();
        uint256 sellerBefore = bob.balance;
        uint256 creatorBefore = alice.balance;

        vm.expectEmit(true, true, false, true, address(nft));
        emit RoyaltyAccrued(tokenId, alice, royalty);

        vm.prank(carol);
        nft.buyArtwork{value: PRICE}(tokenId);

        assertEq(nft.ownerOf(tokenId), carol);
        assertEq(bob.balance, sellerBefore + PRICE - royalty);
        assertEq(alice.balance, creatorBefore);
        assertEq(nft.artistRoyalties(alice), royalty);
        assertEq(address(nft).balance, royalty);
        (, uint256 quoted) = nft.royaltyInfo(tokenId, PRICE);
        assertEq(quoted, royalty);
    }

    function test_WithdrawRoyalties_PaysAccruedAmountOnce() public {
        uint256 tokenId = _mint(alice);
        vm.prank(bob);
        nft.buyArtwork{value: PRICE}(tokenId);
        vm.prank(bob);
        nft.toggleForSale(tokenId);
        vm.prank(carol);
        nft.buyArtwork{value: PRICE}(tokenId);

        uint256 royalty = nft.artistRoyalties(alice);
        uint256 creatorBefore = alice.balance;

        vm.expectEmit(true, false, false, true, address(nft));
        emit RoyaltyPaid(alice, royalty);

        vm.prank(alice);
        nft.withdrawRoyalties();

        assertEq(alice.balance, creatorBefore + royalty);
        assertEq(nft.artistRoyalties(alice), 0);
        assertEq(address(nft).balance, 0);

        vm.prank(alice);
        vm.expectRevert(ArtNFT.NoRoyalties.selector);
        nft.withdrawRoyalties();
    }

    function test_RevertWhen_BuyOwnArtworkOrUnlistedOrUnderpaid() public {
        uint256 tokenId = _mint(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ArtNFT.CannotBuyOwnArtwork.selector, tokenId));
        nft.buyArtwork{value: PRICE}(tokenId);

        vm.prank(alice);
        nft.toggleForSale(tokenId);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ArtNFT.NotForSale.selector, tokenId));
        nft.buyArtwork{value: PRICE}(tokenId);

        vm.prank(alice);
        nft.toggleForSale(tokenId);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ArtNFT.InsufficientPayment.selector, PRICE - 1, PRICE));
        nft.buyArtwork{value: PRICE - 1}(tokenId);
    }

    function test_TransferClearsListing() public {
        uint256 tokenId = _mint(alice);

        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);

        assertEq(nft.ownerOf(tokenId), bob);
        assertFalse(_forSale(tokenId));

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(ArtNFT.NotForSale.selector, tokenId));
        nft.buyArtwork{value: PRICE}(tokenId);
    }

    function test_SetPriceAndToggle_OnlyOwner() public {
        uint256 tokenId = _mint(alice);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ArtNFT.NotTokenOwner.selector, bob, tokenId));
        nft.setPrice(tokenId, 2 ether);

        vm.prank(alice);
        nft.setPrice(tokenId, 2 ether);
        (,, uint256 price,,,) = nft.artworks(tokenId);
        assertEq(price, 2 ether);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ArtNFT.NotTokenOwner.selector, bob, tokenId));
        nft.toggleForSale(tokenId);
    }

    function test_RevertWhen_SellerRejectsEth() public {
        RejectEther seller = new RejectEther();
        vm.prank(address(seller));
        uint256 tokenId = nft.createArtwork("Blue", "Ada", PRICE, ROYALTY_BPS, "ipfs://blue");

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ArtNFT.PaymentFailed.selector, address(seller)));
        nft.buyArtwork{value: PRICE}(tokenId);

        assertEq(nft.ownerOf(tokenId), address(seller));
        assertEq(address(nft).balance, 0);
    }

    function test_BuyArtwork_ReenterDoesNotDoubleSell() public {
        uint256 listedId = _mint(alice);

        ReenteringSeller seller = new ReenteringSeller(nft);
        seller.setTarget(listedId);
        vm.prank(address(seller));
        uint256 soldId = nft.createArtwork("Red", "Gus", PRICE, ROYALTY_BPS, "ipfs://red");

        vm.prank(bob);
        nft.buyArtwork{value: PRICE}(soldId);

        assertEq(seller.attacks(), 1);
        assertEq(nft.ownerOf(soldId), bob);
        assertEq(nft.ownerOf(listedId), alice);
        assertTrue(_forSale(listedId));
        assertEq(address(seller).balance, PRICE);
        assertFalse(_forSale(soldId));
    }

    function test_WithdrawRoyalties_ReenterDoesNotPayTwice() public {
        ReenteringArtist artist = new ReenteringArtist(nft);
        vm.prank(address(artist));
        uint256 tokenId = nft.createArtwork("Blue", "Ada", PRICE, ROYALTY_BPS, "ipfs://blue");

        vm.prank(bob);
        nft.buyArtwork{value: PRICE}(tokenId);
        vm.prank(bob);
        nft.toggleForSale(tokenId);
        vm.prank(carol);
        nft.buyArtwork{value: PRICE}(tokenId);

        uint256 royalty = (PRICE * ROYALTY_BPS) / nft.ROYALTY_DENOMINATOR();
        artist.arm();
        artist.withdraw();

        assertEq(artist.attacks(), 1);
        assertEq(address(artist).balance, PRICE + royalty);
        assertEq(nft.artistRoyalties(address(artist)), 0);

        vm.expectRevert(ArtNFT.NoRoyalties.selector);
        artist.withdraw();
    }

    function test_MintCallbackTransferDoesNotLeaveListing() public {
        MintAndPush minter = new MintAndPush(nft, alice);
        uint256 tokenId = minter.mint();

        assertEq(nft.ownerOf(tokenId), alice);
        assertFalse(_forSale(tokenId));

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ArtNFT.NotForSale.selector, tokenId));
        nft.buyArtwork{value: PRICE}(tokenId);
    }

    function test_CreateArtwork_ContractReceiver() public {
        NFTReceiver receiver = new NFTReceiver();
        vm.prank(address(receiver));
        uint256 tokenId = nft.createArtwork("Blue", "Ada", PRICE, ROYALTY_BPS, "ipfs://blue");
        assertEq(nft.ownerOf(tokenId), address(receiver));
    }

    function testFuzz_SecondarySaleConservesPrice(uint256 price, uint96 royaltyBps, uint256 overpay) public {
        price = bound(price, 1, 1000 ether);
        royaltyBps = uint96(bound(royaltyBps, 0, nft.MAX_ROYALTY()));
        overpay = bound(overpay, 0, 50 ether);

        vm.prank(alice);
        uint256 tokenId = nft.createArtwork("Blue", "Ada", price, royaltyBps, "ipfs://blue");

        vm.deal(bob, price + overpay);
        vm.prank(bob);
        nft.buyArtwork{value: price}(tokenId);

        vm.prank(bob);
        nft.toggleForSale(tokenId);

        uint256 sellerBefore = bob.balance;
        uint256 buyerBefore = price + overpay;
        vm.deal(carol, buyerBefore);

        vm.prank(carol);
        nft.buyArtwork{value: buyerBefore}(tokenId);

        uint256 royalty = royaltyBps == 0 ? 0 : (price * royaltyBps) / nft.ROYALTY_DENOMINATOR();
        assertEq(bob.balance, sellerBefore + price - royalty);
        assertEq(carol.balance, overpay);
        assertEq(nft.artistRoyalties(alice), royalty);
        assertEq(address(nft).balance, royalty);
        (address receiver, uint256 quoted) = nft.royaltyInfo(tokenId, price);
        assertEq(receiver, alice);
        assertEq(quoted, (price * royaltyBps) / nft.ROYALTY_DENOMINATOR());
    }

    function _mint(address artist) internal returns (uint256 tokenId) {
        vm.prank(artist);
        tokenId = nft.createArtwork("Blue", "Ada", PRICE, ROYALTY_BPS, "ipfs://blue");
    }

    function _forSale(uint256 tokenId) internal view returns (bool forSale) {
        (,,, forSale,,) = nft.artworks(tokenId);
    }
}
