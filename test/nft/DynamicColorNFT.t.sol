// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {DynamicColorNFT} from "../../src/nft/DynamicColorNFT.sol";

/// @dev 在铸造回调里读取颜色，确认时间戳在外部调用之前已经写好。
contract MintReader is IERC721Receiver {
    DynamicColorNFT public immutable nft;
    uint256 public seenAt;
    uint256 public seenIndex;

    constructor(DynamicColorNFT nft_) {
        nft = nft_;
    }

    function mint() external returns (uint256 tokenId) {
        tokenId = nft.mint(address(this));
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external returns (bytes4) {
        seenAt = nft.mintedAt(tokenId);
        seenIndex = nft.colorIndexOf(tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract DynamicColorNFTTest is Test {
    DynamicColorNFT internal nft;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    string[7] internal names = [unicode"红", unicode"橙", unicode"黄", unicode"绿", unicode"青", unicode"蓝", unicode"紫"];
    string[7] internal hexes = ["#FF0000", "#FF7F00", "#FFFF00", "#00FF00", "#00FFFF", "#0000FF", "#800080"];

    event ColorMinted(address indexed to, uint256 indexed tokenId, uint256 mintedAt, uint256 colorIndex);

    function setUp() public {
        nft = new DynamicColorNFT();
    }

    function test_EachResidueRendersItsSolidColor() public {
        uint256 base = _baseTimestamp();

        for (uint256 i = 0; i < 7; ++i) {
            vm.warp(base + i);
            vm.prank(alice);
            uint256 tokenId = nft.mint(alice);

            assertEq(nft.mintedAt(tokenId), base + i);
            assertEq(nft.colorIndexOf(tokenId), i);
            assertEq(nft.colorNameOf(tokenId), names[i]);
            assertEq(nft.colorHexOf(tokenId), hexes[i]);
            assertEq(nft.ownerOf(tokenId), alice);

            string memory json = _decodeJson(nft.tokenURI(tokenId));
            assertTrue(_contains(json, names[i]), "metadata missing color name");
            assertTrue(_contains(json, hexes[i]), "metadata missing hex");
            assertTrue(_contains(json, "data:image/svg+xml;base64,"), "metadata missing svg image");

            string memory svg = string(Base64.decode(_stripPrefix(nft.imageURI(tokenId), "data:image/svg+xml;base64,")));
            assertEq(svg, nft.imageSvg(tokenId));
            assertTrue(_contains(svg, string.concat('fill="', hexes[i], '"')), "svg fill mismatch");
        }

        assertEq(nft.totalSupply(), 7);
    }

    function test_MintEmitsColorFromTimestamp() public {
        uint256 base = _baseTimestamp();
        vm.warp(base + 5);

        vm.expectEmit(true, true, false, true, address(nft));
        emit ColorMinted(alice, 0, base + 5, 5);

        vm.prank(alice);
        nft.mint(alice);
    }

    function test_SameTimestampSharesColor_TransferKeepsIt() public {
        uint256 base = _baseTimestamp();
        vm.warp(base + 2);

        vm.prank(alice);
        uint256 first = nft.mint(alice);
        vm.prank(bob);
        uint256 second = nft.mint(bob);

        assertEq(nft.colorIndexOf(first), 2);
        assertEq(nft.colorIndexOf(second), 2);

        vm.prank(alice);
        nft.transferFrom(alice, bob, first);

        assertEq(nft.ownerOf(first), bob);
        assertEq(nft.mintedAt(first), base + 2);
        assertEq(nft.colorHexOf(first), "#FFFF00");
    }

    function test_CallbackSeesStoredMintTimestamp() public {
        uint256 base = _baseTimestamp();
        vm.warp(base + 4);

        MintReader reader = new MintReader(nft);
        uint256 tokenId = reader.mint();

        assertEq(reader.seenAt(), base + 4);
        assertEq(reader.seenIndex(), 4);
        assertEq(nft.colorNameOf(tokenId), unicode"青");
    }

    function test_RevertWhen_MetadataOfUnmintedToken() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
        nft.tokenURI(0);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
        nft.colorIndexOf(0);
    }

    function test_RevertWhen_ColorIndexOutOfRange() public {
        vm.expectRevert(abi.encodeWithSelector(DynamicColorNFT.InvalidColorIndex.selector, 7));
        nft.colorName(7);

        vm.expectRevert(abi.encodeWithSelector(DynamicColorNFT.InvalidColorIndex.selector, 7));
        nft.colorHex(7);
    }

    function testFuzz_ColorIndexIsMintTimestampModulo7(uint32 timestamp) public {
        vm.assume(timestamp > 0);
        vm.warp(timestamp);

        vm.prank(alice);
        uint256 tokenId = nft.mint(alice);

        assertEq(nft.mintedAt(tokenId), timestamp);
        assertEq(nft.colorIndexOf(tokenId), uint256(timestamp) % 7);
        assertEq(nft.colorHexOf(tokenId), hexes[uint256(timestamp) % 7]);
    }

    /// @dev 找一个能被 7 整除的时间戳，后面加 0..6 就能覆盖全部颜色。
    function _baseTimestamp() private view returns (uint256 base) {
        base = block.timestamp == 0 ? 1_700_000_000 : block.timestamp;
        base -= base % 7;
        if (base == 0) base = 7;
    }

    function _decodeJson(string memory uri) private pure returns (string memory) {
        return string(Base64.decode(_stripPrefix(uri, "data:application/json;base64,")));
    }

    function _stripPrefix(string memory value, string memory prefix) private pure returns (string memory) {
        bytes memory valueBytes = bytes(value);
        bytes memory prefixBytes = bytes(prefix);
        require(valueBytes.length >= prefixBytes.length, "prefix longer than value");

        bytes memory out = new bytes(valueBytes.length - prefixBytes.length);
        for (uint256 i = 0; i < out.length; ++i) {
            out[i] = valueBytes[prefixBytes.length + i];
        }
        return string(out);
    }

    function _contains(string memory haystack, string memory needle) private pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) return false;

        for (uint256 i = 0; i <= h.length - n.length; ++i) {
            bool matched = true;
            for (uint256 j = 0; j < n.length; ++j) {
                if (h[i + j] != n[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return true;
        }
        return false;
    }
}
