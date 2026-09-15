// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC721A} from "erc721a/IERC721A.sol";
import {MyERC721ANFT} from "../src/MyERC721ANFT.sol";

contract AcceptReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract RejectReceiver {}

contract MyERC721ANFTTest is Test {
    MyERC721ANFT public nft;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    string constant COLLECTION_URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";

    function setUp() public {
        nft = new MyERC721ANFT(COLLECTION_URI);
    }

    function test_Metadata() public view {
        assertEq(nft.name(), "MyERC721ANFT");
        assertEq(nft.symbol(), "ANFT");
        assertEq(nft.collectionURI(), COLLECTION_URI);
        assertEq(nft.nextTokenId(), 0);
        assertEq(nft.totalSupply(), 0);
        assertEq(nft.MAX_MINT_QUANTITY(), 20);
    }

    function test_Mint_BatchAssignsSequentialIds() public {
        nft.mint(alice, 3);

        assertEq(nft.balanceOf(alice), 3);
        assertEq(nft.totalSupply(), 3);
        assertEq(nft.nextTokenId(), 3);
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.tokenURI(0), COLLECTION_URI);
        assertEq(nft.tokenURI(1), COLLECTION_URI);
        assertEq(nft.tokenURI(2), COLLECTION_URI);
    }

    function test_Mint_IncrementsAcrossCalls() public {
        nft.mint(alice, 2);
        nft.mint(bob, 1);

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), bob);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.nextTokenId(), 3);
        assertEq(nft.totalSupply(), 3);
    }

    function test_Mint_ToZeroAddress_Reverts() public {
        vm.expectRevert(IERC721A.MintToZeroAddress.selector);
        nft.mint(address(0), 1);
    }

    function test_Mint_ZeroQuantity_Reverts() public {
        vm.expectRevert(IERC721A.MintZeroQuantity.selector);
        nft.mint(alice, 0);
    }

    function test_Mint_ExceedsMaxQuantity_Reverts() public {
        uint256 tooMany = nft.MAX_MINT_QUANTITY() + 1;
        vm.expectRevert(MyERC721ANFT.ExceedsMaxMintQuantity.selector);
        nft.mint(alice, tooMany);
    }

    function test_Mint_MaxQuantity() public {
        uint256 maxQty = nft.MAX_MINT_QUANTITY();
        nft.mint(alice, maxQty);

        assertEq(nft.balanceOf(alice), maxQty);
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(maxQty - 1), alice);
        assertEq(nft.nextTokenId(), maxQty);
    }

    function test_Mint_ToNonReceiverContract_Reverts() public {
        RejectReceiver rejector = new RejectReceiver();
        vm.expectRevert(IERC721A.TransferToNonERC721ReceiverImplementer.selector);
        nft.mint(address(rejector), 1);
    }

    function test_Mint_ToReceiverContract() public {
        AcceptReceiver receiver = new AcceptReceiver();
        nft.mint(address(receiver), 2);

        assertEq(nft.ownerOf(0), address(receiver));
        assertEq(nft.ownerOf(1), address(receiver));
        assertEq(nft.balanceOf(address(receiver)), 2);
        assertEq(nft.nextTokenId(), 2);
        assertEq(nft.totalSupply(), 2);
    }

    function test_TokenURI_ForNonexistentToken_Reverts() public {
        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        nft.tokenURI(0);
    }

    function test_Transfer_MiddleTokenAfterBatchMint() public {
        nft.mint(alice, 3);

        vm.prank(alice);
        nft.transferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.balanceOf(bob), 1);
    }

    function testFuzz_Mint_Quantity(uint256 quantity) public {
        quantity = bound(quantity, 1, nft.MAX_MINT_QUANTITY());

        nft.mint(alice, quantity);

        assertEq(nft.balanceOf(alice), quantity);
        assertEq(nft.totalSupply(), quantity);
        assertEq(nft.nextTokenId(), quantity);
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(quantity - 1), alice);
        assertEq(nft.tokenURI(quantity - 1), COLLECTION_URI);
    }
}
