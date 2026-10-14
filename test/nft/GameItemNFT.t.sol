// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {GameItemNFT} from "../../src/nft/GameItemNFT.sol";

/// @dev 测试销毁路径。生产合约没有对外的 burn。
contract GameItemNFTHarness is GameItemNFT {
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}

contract NFTReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract GameItemNFTTest is Test, IERC721Errors {
    GameItemNFT internal nft;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant TOKEN_ID = 1;
    uint256 internal constant DURABILITY = 3;

    event ItemCreated(uint256 indexed tokenId, address indexed player, string name, string itemType, uint256 level);
    event ItemEquipped(uint256 indexed tokenId, address indexed player);
    event ItemUnequipped(uint256 indexed tokenId, address indexed player);
    event ItemUsed(uint256 indexed tokenId, address indexed player, uint256 durability);
    event ItemRepaired(uint256 indexed tokenId, uint256 newDurability);

    function setUp() public {
        vm.prank(owner);
        nft = new GameItemNFT();
    }

    function test_CreateItem_AssignsStatsOwnershipAndInventory() public {
        vm.expectEmit(true, true, false, true, address(nft));
        emit ItemCreated(TOKEN_ID, alice, "Iron Sword", "weapon", 2);

        _create(alice, TOKEN_ID, DURABILITY);

        assertEq(nft.ownerOf(TOKEN_ID), alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.totalItems(), 1);
        assertEq(nft.itemTypeCount("weapon"), 1);
        assertEq(nft.tokenURI(TOKEN_ID), "ipfs://sword");
        assertEq(nft.getPlayerItems(alice).length, 1);
        assertEq(nft.getPlayerItems(alice)[0], TOKEN_ID);
        assertEq(nft.playerItems(alice, 0), TOKEN_ID);

        (
            string memory name,
            string memory itemType,
            uint256 level,
            uint256 attack,
            uint256 defense,
            uint256 durability,
            uint256 maxDurability
        ) = nft.getItemStats(TOKEN_ID);

        assertEq(name, "Iron Sword");
        assertEq(itemType, "weapon");
        assertEq(level, 2);
        assertEq(attack, 10);
        assertEq(defense, 1);
        assertEq(durability, DURABILITY);
        assertEq(maxDurability, DURABILITY);

        (,,,,,,, bool isEquipped) = nft.gameItems(TOKEN_ID);
        assertFalse(isEquipped);
    }

    function test_CreateItem_ToContractReceiver() public {
        NFTReceiver receiver = new NFTReceiver();

        vm.prank(owner);
        nft.createItem(address(receiver), TOKEN_ID, "Shield", "armor", 1, 0, 8, DURABILITY, "ipfs://shield");

        assertEq(nft.ownerOf(TOKEN_ID), address(receiver));
        assertEq(nft.getPlayerItems(address(receiver)).length, 1);
    }

    function test_RevertWhen_CreateItemByNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.createItem(alice, TOKEN_ID, "Iron Sword", "weapon", 2, 10, 1, DURABILITY, "ipfs://sword");
    }

    function test_RevertWhen_CreateItemEmptyName() public {
        vm.prank(owner);
        vm.expectRevert(GameItemNFT.EmptyName.selector);
        nft.createItem(alice, TOKEN_ID, "", "weapon", 1, 1, 1, DURABILITY, "");
    }

    function test_RevertWhen_CreateItemEmptyType() public {
        vm.prank(owner);
        vm.expectRevert(GameItemNFT.EmptyItemType.selector);
        nft.createItem(alice, TOKEN_ID, "Iron Sword", "", 1, 1, 1, DURABILITY, "");
    }

    function test_RevertWhen_CreateItemZeroDurability() public {
        vm.prank(owner);
        vm.expectRevert(GameItemNFT.ZeroDurability.selector);
        nft.createItem(alice, TOKEN_ID, "Iron Sword", "weapon", 1, 1, 1, 0, "");
    }

    function test_RevertWhen_CreateItemToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidReceiver.selector, address(0)));
        nft.createItem(address(0), TOKEN_ID, "Iron Sword", "weapon", 1, 1, 1, DURABILITY, "");
    }

    function test_RevertWhen_CreateItemDuplicateId() public {
        _create(alice, TOKEN_ID, DURABILITY);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidSender.selector, address(0)));
        nft.createItem(bob, TOKEN_ID, "Axe", "weapon", 1, 1, 1, DURABILITY, "");

        assertEq(nft.totalItems(), 1);
        assertEq(nft.ownerOf(TOKEN_ID), alice);
    }

    function test_EquipAndUnequip() public {
        _create(alice, TOKEN_ID, DURABILITY);

        vm.expectEmit(true, true, false, true, address(nft));
        emit ItemEquipped(TOKEN_ID, alice);
        vm.prank(alice);
        nft.equipItem(TOKEN_ID);
        (,,,,,,, bool equipped) = nft.gameItems(TOKEN_ID);
        assertTrue(equipped);

        vm.expectEmit(true, true, false, true, address(nft));
        emit ItemUnequipped(TOKEN_ID, alice);
        vm.prank(alice);
        nft.unequipItem(TOKEN_ID);
        (,,,,,,, equipped) = nft.gameItems(TOKEN_ID);
        assertFalse(equipped);
    }

    function test_RevertWhen_EquipByNonOwnerOrTwiceOrWhenBroken() public {
        _create(alice, TOKEN_ID, 1);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(GameItemNFT.NotItemOwner.selector, bob, TOKEN_ID));
        nft.equipItem(TOKEN_ID);

        vm.prank(alice);
        nft.equipItem(TOKEN_ID);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GameItemNFT.AlreadyEquipped.selector, TOKEN_ID));
        nft.equipItem(TOKEN_ID);

        vm.prank(alice);
        nft.useItem(TOKEN_ID);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GameItemNFT.ItemBroken.selector, TOKEN_ID));
        nft.equipItem(TOKEN_ID);
    }

    function test_RevertWhen_UnequipNotEquipped() public {
        _create(alice, TOKEN_ID, DURABILITY);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GameItemNFT.NotEquipped.selector, TOKEN_ID));
        nft.unequipItem(TOKEN_ID);
    }

    function test_UseItem_ReducesDurabilityAndUnequipsAtZero() public {
        _create(alice, TOKEN_ID, 1);
        vm.prank(alice);
        nft.equipItem(TOKEN_ID);

        vm.expectEmit(true, true, false, true, address(nft));
        emit ItemUsed(TOKEN_ID, alice, 0);
        vm.expectEmit(true, true, false, true, address(nft));
        emit ItemUnequipped(TOKEN_ID, alice);

        vm.prank(alice);
        nft.useItem(TOKEN_ID);

        (,,,,, uint256 durability,, bool equipped) = nft.gameItems(TOKEN_ID);
        assertEq(durability, 0);
        assertFalse(equipped);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GameItemNFT.ItemBroken.selector, TOKEN_ID));
        nft.useItem(TOKEN_ID);
    }

    function test_UseItem_WhenUnequippedDoesNotEmitUnequip() public {
        _create(alice, TOKEN_ID, DURABILITY);

        vm.recordLogs();
        vm.prank(alice);
        nft.useItem(TOKEN_ID);
        assertEq(vm.getRecordedLogs().length, 1);

        (,,,,, uint256 durability,, bool equipped) = nft.gameItems(TOKEN_ID);
        assertEq(durability, DURABILITY - 1);
        assertFalse(equipped);
    }

    function test_RepairItem_RestoresMaxAndAllowsEquipAgain() public {
        _create(alice, TOKEN_ID, 1);
        vm.startPrank(alice);
        nft.useItem(TOKEN_ID);

        vm.expectEmit(true, false, false, true, address(nft));
        emit ItemRepaired(TOKEN_ID, 1);
        nft.repairItem(TOKEN_ID);
        nft.equipItem(TOKEN_ID);
        vm.stopPrank();

        (,,,,, uint256 durability, uint256 maxDurability, bool equipped) = nft.gameItems(TOKEN_ID);
        assertEq(durability, maxDurability);
        assertTrue(equipped);
    }

    function test_RevertWhen_RepairAtMaxDurability() public {
        _create(alice, TOKEN_ID, DURABILITY);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GameItemNFT.AlreadyAtMaxDurability.selector, TOKEN_ID));
        nft.repairItem(TOKEN_ID);
    }

    function test_Transfer_MovesInventoryAndUnequips() public {
        _create(alice, TOKEN_ID, DURABILITY);
        _create(alice, 2, DURABILITY);
        vm.prank(alice);
        nft.equipItem(TOKEN_ID);

        vm.expectEmit(true, true, false, true, address(nft));
        emit ItemUnequipped(TOKEN_ID, alice);

        vm.prank(alice);
        nft.transferFrom(alice, bob, TOKEN_ID);

        assertEq(nft.ownerOf(TOKEN_ID), bob);
        assertEq(nft.getPlayerItems(alice).length, 1);
        assertEq(nft.getPlayerItems(alice)[0], 2);
        assertEq(nft.getPlayerItems(bob).length, 1);
        assertEq(nft.getPlayerItems(bob)[0], TOKEN_ID);
        assertEq(nft.totalItems(), 2);
        assertEq(nft.itemTypeCount("weapon"), 2);

        (,,,,,,, bool equipped) = nft.gameItems(TOKEN_ID);
        assertFalse(equipped);

        vm.prank(bob);
        nft.equipItem(TOKEN_ID);

        // token 2 是被交换到下标 0 的，再转一次才能证明 _heldIndex 跟着更新了。
        vm.prank(alice);
        nft.transferFrom(alice, bob, 2);
        assertEq(nft.getPlayerItems(alice).length, 0);
        assertEq(nft.getPlayerItems(bob).length, 2);
        assertEq(nft.ownerOf(2), bob);
    }

    function test_Burn_RemovesMiddleItemAndAllowsRemint() public {
        vm.prank(owner);
        GameItemNFTHarness harness = new GameItemNFTHarness();

        vm.startPrank(owner);
        harness.createItem(alice, 1, "Sword", "weapon", 1, 1, 1, DURABILITY, "ipfs://1");
        harness.createItem(alice, 2, "Bow", "weapon", 1, 1, 1, DURABILITY, "ipfs://2");
        harness.createItem(alice, 3, "Staff", "weapon", 1, 1, 1, DURABILITY, "ipfs://3");
        vm.stopPrank();

        vm.prank(alice);
        harness.equipItem(2);
        harness.burn(2);

        assertEq(harness.totalItems(), 2);
        assertEq(harness.itemTypeCount("weapon"), 2);
        assertEq(harness.getPlayerItems(alice).length, 2);
        assertEq(harness.getPlayerItems(alice)[0], 1);
        assertEq(harness.getPlayerItems(alice)[1], 3);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, 2));
        harness.ownerOf(2);

        vm.prank(alice);
        harness.transferFrom(alice, bob, 3);
        assertEq(harness.ownerOf(3), bob);
        assertEq(harness.getPlayerItems(alice).length, 1);
        assertEq(harness.getPlayerItems(alice)[0], 1);

        vm.prank(owner);
        harness.createItem(bob, 2, "Bow", "weapon", 1, 1, 1, DURABILITY, "ipfs://2b");
        assertEq(harness.ownerOf(2), bob);
        assertEq(harness.totalItems(), 3);
        assertEq(harness.getPlayerItems(bob).length, 2);
    }

    function test_RevertWhen_StatsOfMissingToken() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, TOKEN_ID));
        nft.getItemStats(TOKEN_ID);
    }

    function testFuzz_UseThenRepairRoundTrip(uint256 durability, uint256 uses) public {
        durability = bound(durability, 1, 500);
        uses = bound(uses, 1, durability);

        _create(alice, TOKEN_ID, durability);

        vm.startPrank(alice);
        for (uint256 i = 0; i < uses; ++i) {
            nft.useItem(TOKEN_ID);
        }
        (,,,,, uint256 left,,) = nft.gameItems(TOKEN_ID);
        assertEq(left, durability - uses);

        if (uses > 0 && left < durability) {
            nft.repairItem(TOKEN_ID);
        }
        vm.stopPrank();

        (,,,,, uint256 restored,, bool equipped) = nft.gameItems(TOKEN_ID);
        assertEq(restored, durability);
        assertFalse(equipped);
    }

    function _create(address to, uint256 tokenId, uint256 durability) internal {
        vm.prank(owner);
        nft.createItem(to, tokenId, "Iron Sword", "weapon", 2, 10, 1, durability, "ipfs://sword");
    }
}
