// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {GameEconomy2} from "../../src/erc-1155/GameEconomy2.sol";

/// @dev 收到剑之后，再从已授权的受害者那里转第二把剑。外层互换已经完成记账，这次应被装备上限拦住。
contract SwordGrabber is IERC1155Receiver {
    GameEconomy2 internal game;
    address internal victim;
    bool internal tried;

    function init(GameEconomy2 game_, address victim_) external {
        game = game_;
        victim = victim_;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        if (!tried) {
            tried = true;
            game.safeTransferFrom(victim, address(this), game.SWORD(), 1, "");
        }
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

contract GameEconomy2Test is Test, IERC1155Errors {
    uint256 internal constant CURRENCY_SUPPLY = 1_000_000;
    uint256 internal constant EQUIPMENT_SUPPLY = 1_000;
    uint256 internal constant CONSUMABLE_SUPPLY = 10_000;

    GameEconomy2 internal game;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal gold;
    uint256 internal sword;
    uint256 internal shield;
    uint256 internal potion;
    uint256 internal scroll;

    event ItemCreated(uint256 indexed id, string name, string itemType, bool isFungible);
    event ItemTraded(address indexed from, address indexed to, uint256[] ids, uint256[] amounts);
    event StatsUpdated(address indexed player, uint256 attack, uint256 defense);

    function setUp() public {
        game = new GameEconomy2();
        gold = game.GOLD_COIN();
        sword = game.SWORD();
        shield = game.SHIELD();
        potion = game.POTION();
        scroll = game.SCROLL();
        _createCatalog();
    }

    function test_CreateItem_StoresMetadata() public view {
        assertEq(game.owner(), address(this));
        (
            string memory name,
            string memory itemType,
            uint256 level,
            uint256 attack,
            uint256 defense,
            bool fungible,
            uint256 maxSupply
        ) = game.itemInfo(sword);
        assertEq(name, "Sword");
        assertEq(itemType, "weapon");
        assertEq(level, 1);
        assertEq(attack, 25);
        assertEq(defense, 0);
        assertFalse(fungible);
        assertEq(maxSupply, EQUIPMENT_SUPPLY);
        assertEq(game.uri(sword), "https://example.com/game/sword.json");
        assertEq(game.uri(gold), "https://example.com/game/gold.json");
    }

    function test_RevertWhen_CreateDuplicateOrZeroSupply() public {
        vm.expectRevert(bytes("Item already exists"));
        game.createItem(sword, "Sword", "weapon", 1, 25, 0, false, 10, "again.json");

        vm.expectRevert(bytes("Zero max supply"));
        game.createItem(42, "Ghost", "misc", 1, 0, 0, true, 0, "ghost.json");
        (,,,,,, uint256 maxSupply) = game.itemInfo(42);
        assertEq(maxSupply, 0);
    }

    function test_RevertWhen_NonOwnerCreatesOrMints(address caller) public {
        vm.assume(caller != address(this) && caller != address(0));
        vm.startPrank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        game.createItem(42, "Ghost", "misc", 1, 0, 0, true, 1, "ghost.json");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        game.mintItem(caller, gold, 1);
        vm.stopPrank();
        assertEq(game.balanceOf(caller, gold), 0);
    }

    function test_MintItem_UpdatesInventoryAndStats() public {
        vm.expectEmit(true, false, false, true, address(game));
        emit StatsUpdated(alice, 25, 0);
        game.mintItem(alice, sword, 1);
        game.mintItem(alice, shield, 1);
        game.mintItem(alice, gold, 100);
        game.mintItem(alice, potion, 3);

        assertEq(game.balanceOf(alice, sword), 1);
        assertEq(game.balanceOf(alice, shield), 1);
        assertEq(game.balanceOf(alice, gold), 100);
        assertEq(game.totalSupply(sword), 1);
        assertEq(game.totalSupply(gold), 100);

        uint256[] memory inventory = game.getPlayerInventory(alice);
        assertEq(inventory.length, 4);
        assertTrue(_contains(inventory, sword));
        assertTrue(_contains(inventory, shield));
        assertTrue(_contains(inventory, gold));
        assertTrue(_contains(inventory, potion));

        (uint256 attack, uint256 defense) = game.getPlayerStats(alice);
        assertEq(attack, 25);
        assertEq(defense, 20);
    }

    function test_RevertWhen_MintUnknownExceedsSupplyOrStacksEquipment() public {
        vm.expectRevert(bytes("Item does not exist"));
        game.mintItem(alice, 42, 1);

        vm.expectRevert(bytes("Zero amount"));
        game.mintItem(alice, potion, 0);

        game.mintItem(alice, sword, 1);
        vm.expectRevert(bytes("Equipment limit"));
        game.mintItem(alice, sword, 1);
        assertEq(game.balanceOf(alice, sword), 1);

        vm.expectRevert(bytes("Equipment amount"));
        game.mintItem(bob, shield, 2);
        assertEq(game.balanceOf(bob, shield), 0);

        game.mintItem(alice, potion, CONSUMABLE_SUPPLY);
        vm.expectRevert(bytes("Exceeds max supply"));
        game.mintItem(bob, potion, 1);
        assertEq(game.totalSupply(potion), CONSUMABLE_SUPPLY);
        assertEq(game.balanceOf(bob, potion), 0);
    }

    function testFuzz_MintPotion_WithinSupply(uint96 amount) public {
        amount = uint96(bound(amount, 1, CONSUMABLE_SUPPLY));
        game.mintItem(alice, potion, amount);
        assertEq(game.balanceOf(alice, potion), amount);
        assertEq(game.totalSupply(potion), amount);
        (uint256 attack, uint256 defense) = game.getPlayerStats(alice);
        assertEq(attack, 0);
        assertEq(defense, 0);
    }

    function test_UseConsumable_BurnsAndRecordsEffect() public {
        game.mintItem(alice, potion, 3);
        game.mintItem(alice, scroll, 2);

        vm.prank(alice);
        game.useConsumable(potion, 2);
        vm.prank(alice);
        game.useConsumable(scroll, 2);

        assertEq(game.balanceOf(alice, potion), 1);
        assertEq(game.balanceOf(alice, scroll), 0);
        assertEq(game.totalSupply(potion), 1);
        assertEq(game.totalSupply(scroll), 0);
        assertEq(game.playerStats(alice, potion), 20);
        assertEq(game.playerStats(alice, scroll), 10);

        uint256[] memory inventory = game.getPlayerInventory(alice);
        assertTrue(_contains(inventory, potion));
        assertFalse(_contains(inventory, scroll));
    }

    function test_RevertWhen_UseNonConsumableOrTooMany() public {
        game.mintItem(alice, gold, 5);
        game.mintItem(alice, sword, 1);
        game.mintItem(alice, potion, 1);

        vm.startPrank(alice);
        vm.expectRevert(bytes("Not a consumable"));
        game.useConsumable(gold, 1);
        vm.expectRevert(bytes("Not a consumable"));
        game.useConsumable(sword, 1);
        vm.expectRevert(bytes("Zero amount"));
        game.useConsumable(potion, 0);
        vm.expectRevert(abi.encodeWithSelector(ERC1155InsufficientBalance.selector, alice, 1, 2, potion));
        game.useConsumable(potion, 2);
        vm.stopPrank();

        assertEq(game.balanceOf(alice, gold), 5);
        assertEq(game.balanceOf(alice, sword), 1);
        assertEq(game.balanceOf(alice, potion), 1);
        assertEq(game.playerStats(alice, potion), 0);
    }

    function test_Trade_SwapSwordForShield_UpdatesStats() public {
        game.mintItem(alice, sword, 1);
        game.mintItem(bob, shield, 1);
        vm.prank(bob);
        game.setApprovalForAll(alice, true);

        uint256[] memory giveIds = _one(sword);
        uint256[] memory giveAmounts = _one(1);
        vm.expectEmit(true, true, false, true, address(game));
        emit ItemTraded(alice, bob, giveIds, giveAmounts);

        vm.prank(alice);
        game.tradeItems(alice, bob, giveIds, giveAmounts, _one(shield), _one(1));

        assertEq(game.balanceOf(alice, sword), 0);
        assertEq(game.balanceOf(alice, shield), 1);
        assertEq(game.balanceOf(bob, sword), 1);
        assertEq(game.balanceOf(bob, shield), 0);

        (uint256 aliceAttack, uint256 aliceDefense) = game.getPlayerStats(alice);
        (uint256 bobAttack, uint256 bobDefense) = game.getPlayerStats(bob);
        assertEq(aliceAttack, 0);
        assertEq(aliceDefense, 20);
        assertEq(bobAttack, 25);
        assertEq(bobDefense, 0);

        uint256[] memory aliceItems = game.getPlayerInventory(alice);
        assertFalse(_contains(aliceItems, sword));
        assertTrue(_contains(aliceItems, shield));
    }

    /// @notice 两边各有一把剑时，互换完成后每人仍是 1 把，不应被中间余额拦住。
    function test_Trade_SwapIdenticalSwords() public {
        game.mintItem(alice, sword, 1);
        game.mintItem(bob, sword, 1);
        vm.prank(bob);
        game.setApprovalForAll(alice, true);

        vm.prank(alice);
        game.tradeItems(alice, bob, _one(sword), _one(1), _one(sword), _one(1));

        assertEq(game.balanceOf(alice, sword), 1);
        assertEq(game.balanceOf(bob, sword), 1);
        (uint256 attack,) = game.getPlayerStats(alice);
        assertEq(attack, 25);
    }

    function test_Trade_BatchGift() public {
        game.mintItem(alice, gold, 10);
        game.mintItem(alice, potion, 2);

        uint256[] memory ids = new uint256[](2);
        ids[0] = gold;
        ids[1] = potion;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 2;

        vm.prank(alice);
        game.tradeItems(alice, bob, ids, amounts, new uint256[](0), new uint256[](0));

        assertEq(game.balanceOf(alice, gold), 0);
        assertEq(game.balanceOf(bob, gold), 10);
        assertEq(game.balanceOf(bob, potion), 2);
    }

    function test_Trade_GiftWithoutRecipientApproval() public {
        game.mintItem(alice, potion, 5);

        vm.prank(alice);
        game.tradeItems(alice, bob, _one(potion), _one(5), new uint256[](0), new uint256[](0));

        assertEq(game.balanceOf(alice, potion), 0);
        assertEq(game.balanceOf(bob, potion), 5);
        uint256[] memory bobItems = game.getPlayerInventory(bob);
        assertEq(bobItems.length, 1);
        assertEq(bobItems[0], potion);
    }

    function test_Trade_ByOperator() public {
        game.mintItem(alice, gold, 20);
        game.mintItem(bob, potion, 2);
        vm.prank(alice);
        game.setApprovalForAll(carol, true);
        vm.prank(bob);
        game.setApprovalForAll(carol, true);

        vm.prank(carol);
        game.tradeItems(alice, bob, _one(gold), _one(20), _one(potion), _one(2));

        assertEq(game.balanceOf(bob, gold), 20);
        assertEq(game.balanceOf(alice, potion), 2);
    }

    function test_RevertWhen_TradeWithoutCounterpartyApproval() public {
        game.mintItem(alice, potion, 1);
        game.mintItem(bob, potion, 1);

        vm.expectRevert(bytes("Not authorized"));
        vm.prank(alice);
        game.tradeItems(alice, bob, _one(potion), _one(1), _one(potion), _one(1));

        vm.expectRevert(bytes("Not authorized"));
        vm.prank(bob);
        game.tradeItems(alice, bob, _one(potion), _one(1), new uint256[](0), new uint256[](0));

        assertEq(game.balanceOf(alice, potion), 1);
        assertEq(game.balanceOf(bob, potion), 1);
    }

    function test_RevertWhen_TradeWouldStackEquipment() public {
        game.mintItem(alice, sword, 1);
        game.mintItem(bob, sword, 1);
        vm.prank(bob);
        game.setApprovalForAll(alice, true);

        vm.expectRevert(bytes("Equipment limit"));
        vm.prank(alice);
        game.tradeItems(alice, bob, new uint256[](0), new uint256[](0), _one(sword), _one(1));

        vm.expectRevert(bytes("Equipment limit"));
        vm.prank(alice);
        game.safeTransferFrom(alice, bob, sword, 1, "");

        assertEq(game.balanceOf(alice, sword), 1);
        assertEq(game.balanceOf(bob, sword), 1);
    }

    function test_RevertWhen_TradeBundleInvalid() public {
        game.mintItem(alice, potion, 5);
        game.mintItem(bob, potion, 5);
        vm.prank(bob);
        game.setApprovalForAll(alice, true);

        vm.startPrank(alice);
        vm.expectRevert(bytes("Empty trade"));
        game.tradeItems(alice, bob, new uint256[](0), new uint256[](0), new uint256[](0), new uint256[](0));

        vm.expectRevert(bytes("Arrays length mismatch"));
        game.tradeItems(alice, bob, _one(potion), new uint256[](0), new uint256[](0), new uint256[](0));

        uint256[] memory ids = new uint256[](2);
        ids[0] = potion;
        ids[1] = potion;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        vm.expectRevert(bytes("Duplicate id"));
        game.tradeItems(alice, bob, ids, amounts, new uint256[](0), new uint256[](0));

        vm.expectRevert(bytes("Unknown item"));
        game.tradeItems(alice, bob, _one(42), _one(1), new uint256[](0), new uint256[](0));

        vm.expectRevert(bytes("Same address"));
        game.tradeItems(alice, alice, _one(potion), _one(1), new uint256[](0), new uint256[](0));

        vm.expectRevert(bytes("Equipment amount"));
        game.tradeItems(alice, bob, _one(sword), _one(2), new uint256[](0), new uint256[](0));
        vm.stopPrank();

        assertEq(game.balanceOf(alice, potion), 5);
    }

    function test_RevertWhen_TradeInsufficientBalance() public {
        game.mintItem(bob, potion, 1);
        vm.prank(bob);
        game.setApprovalForAll(alice, true);

        vm.expectRevert(abi.encodeWithSelector(ERC1155InsufficientBalance.selector, alice, 0, 1, potion));
        vm.prank(alice);
        game.tradeItems(alice, bob, _one(potion), _one(1), new uint256[](0), new uint256[](0));
        assertEq(game.balanceOf(bob, potion), 1);
    }

    function test_Trade_ReentrancyCannotStackSword() public {
        SwordGrabber grabber = new SwordGrabber();
        grabber.init(game, carol);
        game.mintItem(alice, sword, 1);
        game.mintItem(carol, sword, 1);
        vm.prank(carol);
        game.setApprovalForAll(address(grabber), true);

        vm.expectRevert(bytes("Equipment limit"));
        vm.prank(alice);
        game.tradeItems(alice, address(grabber), _one(sword), _one(1), new uint256[](0), new uint256[](0));

        assertEq(game.balanceOf(alice, sword), 1);
        assertEq(game.balanceOf(carol, sword), 1);
        assertEq(game.balanceOf(address(grabber), sword), 0);
    }

    function _createCatalog() private {
        game.createItem(
            gold, "Gold Coin", "currency", 1, 0, 0, true, CURRENCY_SUPPLY, "https://example.com/game/gold.json"
        );
        game.createItem(
            game.SILVER_COIN(),
            "Silver Coin",
            "currency",
            1,
            0,
            0,
            true,
            CURRENCY_SUPPLY,
            "https://example.com/game/silver.json"
        );
        game.createItem(
            game.COPPER_COIN(),
            "Copper Coin",
            "currency",
            1,
            0,
            0,
            true,
            CURRENCY_SUPPLY,
            "https://example.com/game/copper.json"
        );
        game.createItem(
            sword, "Sword", "weapon", 1, 25, 0, false, EQUIPMENT_SUPPLY, "https://example.com/game/sword.json"
        );
        game.createItem(
            shield, "Shield", "armor", 1, 0, 20, false, EQUIPMENT_SUPPLY, "https://example.com/game/shield.json"
        );
        game.createItem(
            potion, "Potion", "consumable", 1, 0, 0, true, CONSUMABLE_SUPPLY, "https://example.com/game/potion.json"
        );
        game.createItem(
            scroll, "Scroll", "consumable", 1, 0, 0, true, CONSUMABLE_SUPPLY, "https://example.com/game/scroll.json"
        );
    }

    function _one(uint256 value) private pure returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = value;
    }

    function _contains(uint256[] memory ids, uint256 id) private pure returns (bool) {
        for (uint256 i = 0; i < ids.length; ++i) {
            if (ids[i] == id) return true;
        }
        return false;
    }
}
