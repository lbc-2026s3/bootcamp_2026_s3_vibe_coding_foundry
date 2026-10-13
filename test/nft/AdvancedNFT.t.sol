// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {AdvancedNFT} from "../../src/nft/AdvancedNFT.sol";

contract AdvancedNFTReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract AdvancedNFTTest is Test, IERC721Errors {
    AdvancedNFT internal nft;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    event NFTMinted(address indexed to, uint256 indexed tokenId, AdvancedNFT.NFTAttributes attributes);
    event AttributesUpdated(uint256 indexed tokenId, AdvancedNFT.NFTAttributes attributes);

    function setUp() public {
        nft = new AdvancedNFT();
    }

    function test_Mint_StoresAttributesAndCountsRarity() public {
        AdvancedNFT.NFTAttributes memory attributes = _attributes("Dragon", "A dragon", "ipfs://dragon", 3, 2, 10, true);

        vm.expectEmit(true, true, false, true, address(nft));
        emit NFTMinted(bob, 0, attributes);

        uint256 tokenId = nft.mintNFT(bob, "Dragon", "A dragon", "ipfs://dragon", 3, 2, 10, true);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), bob);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.rarityCount(3), 1);
        assertEq(nft.owner(), address(this));

        AdvancedNFT.NFTAttributes memory stored = nft.getAttributes(tokenId);
        assertEq(stored.name, "Dragon");
        assertEq(stored.description, "A dragon");
        assertEq(stored.image, "ipfs://dragon");
        assertEq(stored.rarity, 3);
        assertEq(stored.level, 2);
        assertEq(stored.power, 10);
        assertTrue(stored.isSpecial);
    }

    function test_Mint_AssignsSequentialIds() public {
        uint256 first = nft.mintNFT(alice, "A", "a", "ipfs://a", 1, 1, 1, false);
        uint256 second = nft.mintNFT(bob, "B", "b", "ipfs://b", 5, 9, 99, true);

        assertEq(first, 0);
        assertEq(second, 1);
        assertEq(nft.totalSupply(), 2);
        assertEq(nft.rarityCount(1), 1);
        assertEq(nft.rarityCount(5), 1);
    }

    /// @notice 模糊测试。带参数的 test 函数不会手工传参，Forge 每次填一个随机数再跑一遍。
    /// @param rarity 稀有度。只保留 0 或大于 5 的值；1 到 5 会铸造成功，进不了 expectRevert。
    function test_RevertWhen_RarityOutOfRange(uint256 rarity) public {
        vm.assume(rarity == 0 || rarity > 5);
        vm.expectRevert(bytes("Invalid rarity"));
        nft.mintNFT(alice, "A", "a", "ipfs://a", rarity, 1, 1, false);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.mintNFT(alice, "A", "a", "ipfs://a", 1, 1, 1, false);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidReceiver.selector, address(0)));
        nft.mintNFT(address(0), "A", "a", "ipfs://a", 1, 1, 1, false);
        assertEq(nft.totalSupply(), 0);
        assertEq(nft.rarityCount(1), 0);
    }

    function test_Mint_ToContractReceiver() public {
        AdvancedNFTReceiver receiver = new AdvancedNFTReceiver();
        uint256 tokenId = nft.mintNFT(address(receiver), "A", "a", "ipfs://a", 2, 1, 1, false);
        assertEq(nft.ownerOf(tokenId), address(receiver));
    }

    function test_RevertWhen_MintToContractWithoutReceiver() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidReceiver.selector, address(this)));
        nft.mintNFT(address(this), "A", "a", "ipfs://a", 1, 1, 1, false);
    }

    function test_Update_MovesRarityCount() public {
        nft.mintNFT(alice, "A", "a", "ipfs://a", 1, 1, 1, false);
        nft.mintNFT(bob, "B", "b", "ipfs://b", 1, 1, 1, false);

        AdvancedNFT.NFTAttributes memory updated = _attributes("A2", "desc", "ipfs://a2", 4, 7, 70, true);
        vm.expectEmit(true, false, false, true, address(nft));
        emit AttributesUpdated(0, updated);

        nft.updateAttributes(0, "A2", "desc", "ipfs://a2", 4, 7, 70, true);

        AdvancedNFT.NFTAttributes memory stored = nft.getAttributes(0);
        assertEq(stored.name, "A2");
        assertEq(stored.rarity, 4);
        assertEq(stored.level, 7);
        assertEq(stored.power, 70);
        assertTrue(stored.isSpecial);
        assertEq(nft.rarityCount(1), 1);
        assertEq(nft.rarityCount(4), 1);
        assertEq(nft.ownerOf(0), alice);
    }

    function test_Update_SameRarityKeepsCount() public {
        nft.mintNFT(alice, "A", "a", "ipfs://a", 2, 1, 1, false);
        nft.updateAttributes(0, "A", "a", "ipfs://a", 2, 3, 8, false);
        assertEq(nft.rarityCount(2), 1);
        assertEq(nft.getAttributes(0).level, 3);
    }

    function test_RevertWhen_UpdateMissingToken() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, 0));
        nft.updateAttributes(0, "A", "a", "ipfs://a", 1, 1, 1, false);
    }

    function test_RevertWhen_UpdateRarityOutOfRange() public {
        nft.mintNFT(alice, "A", "a", "ipfs://a", 1, 1, 1, false);
        vm.expectRevert(bytes("Invalid rarity"));
        nft.updateAttributes(0, "A", "a", "ipfs://a", 6, 1, 1, false);
        assertEq(nft.rarityCount(1), 1);
    }

    function test_RevertWhen_NonOwnerUpdates() public {
        nft.mintNFT(alice, "A", "a", "ipfs://a", 1, 1, 1, false);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.updateAttributes(0, "A", "a", "ipfs://a", 2, 1, 1, false);
    }

    function test_RevertWhen_GetAttributesForUnminted() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, 0));
        nft.getAttributes(0);
    }

    function test_GetRarityStats_LeavesIndexZeroEmpty() public {
        nft.mintNFT(alice, "A", "a", "ipfs://a", 1, 1, 1, false);
        nft.mintNFT(alice, "B", "b", "ipfs://b", 1, 1, 1, false);
        nft.mintNFT(bob, "C", "c", "ipfs://c", 5, 1, 1, true);

        uint256[6] memory stats = nft.getRarityStats();
        assertEq(stats[0], 0);
        assertEq(stats[1], 2);
        assertEq(stats[2], 0);
        assertEq(stats[5], 1);
    }

    function test_TokenURI_DecodesToMetadata() public {
        nft.mintNFT(bob, "Dragon", "A dragon", "ipfs://dragon", 3, 2, 10, true);

        string memory json = _decodedTokenJson(0);
        assertEq(
            json,
            '{"name":"Dragon","description":"A dragon","image":"ipfs://dragon","attributes":[{"trait_type":"Rarity","value":3},{"trait_type":"Level","value":2},{"trait_type":"Power","value":10},{"trait_type":"Special","value":true}]}'
        );
    }

    function test_TokenURI_EscapesQuotesAndBackslash() public {
        nft.mintNFT(alice, 'a"b', "line\n", "ipfs://x\\y", 1, 0, 0, false);

        string memory json = _decodedTokenJson(0);
        assertEq(
            json,
            '{"name":"a\\"b","description":"line\\n","image":"ipfs://x\\\\y","attributes":[{"trait_type":"Rarity","value":1},{"trait_type":"Level","value":0},{"trait_type":"Power","value":0},{"trait_type":"Special","value":false}]}'
        );
    }

    function test_RevertWhen_TokenURIForUnminted() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, 0));
        nft.tokenURI(0);
    }

    function testFuzz_Mint_AcceptsRarityInRange(uint256 rarity, uint256 level, uint256 power, bool isSpecial) public {
        rarity = bound(rarity, 1, 5);
        uint256 tokenId = nft.mintNFT(alice, "Fuzz", "desc", "ipfs://fuzz", rarity, level, power, isSpecial);

        AdvancedNFT.NFTAttributes memory stored = nft.getAttributes(tokenId);
        assertEq(stored.rarity, rarity);
        assertEq(stored.level, level);
        assertEq(stored.power, power);
        assertEq(stored.isSpecial, isSpecial);
        assertEq(nft.rarityCount(rarity), 1);
        assertEq(nft.ownerOf(tokenId), alice);
    }

    function _attributes(
        string memory name,
        string memory description,
        string memory image,
        uint256 rarity,
        uint256 level,
        uint256 power,
        bool isSpecial
    ) internal pure returns (AdvancedNFT.NFTAttributes memory) {
        return AdvancedNFT.NFTAttributes({
            name: name,
            description: description,
            image: image,
            rarity: rarity,
            level: level,
            power: power,
            isSpecial: isSpecial
        });
    }

    function _decodedTokenJson(uint256 tokenId) internal view returns (string memory) {
        bytes memory uri = bytes(nft.tokenURI(tokenId));
        bytes memory prefix = bytes("data:application/json;base64,");
        bytes memory encoded = new bytes(uri.length - prefix.length);
        for (uint256 i = 0; i < encoded.length; ++i) {
            encoded[i] = uri[prefix.length + i];
        }
        return string(Base64.decode(string(encoded)));
    }
}
