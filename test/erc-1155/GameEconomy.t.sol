// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {GameEconomy} from "../../src/erc-1155/GameEconomy.sol";

/// @dev 购买药水时，接收回调里再买一次。外层购买已经占着重入锁，内层应失败。
contract ReenteringBuyer is IERC1155Receiver {
    GameEconomy internal game;
    bool internal attempted;

    function setGame(GameEconomy game_) external {
        game = game_;
    }

    function buyPotion() external {
        game.buyItem(game.POTION(), 1);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        if (!attempted) {
            attempted = true;
            try game.buyItem(game.POTION(), 1) {} catch {}
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

contract GameEconomyTest is Test, IERC1155Errors {
    GameEconomy internal game;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal gold;
    uint256 internal silver;
    uint256 internal sword;
    uint256 internal shield;
    uint256 internal potion;

    event StarterClaimed(address indexed player);
    event RewardMinted(address indexed to, uint256 indexed id, uint256 amount);
    event ItemBought(address indexed buyer, uint256 indexed id, uint256 amount, uint256 goldSpent);
    event ItemsTraded(address indexed from, address indexed to);
    event PotionUsed(address indexed account, uint256 amount);

    function setUp() public {
        game = new GameEconomy();
        gold = game.GOLD_COIN();
        silver = game.SILVER_COIN();
        sword = game.SWORD();
        shield = game.SHIELD();
        potion = game.POTION();
    }

    function test_MetadataAndPrices() public view {
        assertEq(game.owner(), address(this));
        assertEq(game.uri(sword), "https://example.com/game/{id}.json");
        assertTrue(game.isFungible(gold));
        assertTrue(game.isFungible(silver));
        assertTrue(game.isFungible(potion));
        assertFalse(game.isFungible(sword));
        assertFalse(game.isFungible(shield));
        assertEq(game.priceOf(sword), 100);
        assertEq(game.priceOf(shield), 80);
        assertEq(game.priceOf(potion), 10);
        assertEq(game.priceOf(gold), 0);
    }

    function test_ClaimStarterPack_MintsOnce() public {
        vm.expectEmit(true, false, false, true, address(game));
        emit StarterClaimed(alice);

        vm.prank(alice);
        game.claimStarterPack();

        assertEq(game.balanceOf(alice, gold), game.STARTER_GOLD());
        assertEq(game.balanceOf(alice, potion), game.STARTER_POTION());
        assertTrue(game.starterClaimed(alice));

        vm.expectRevert(bytes("Already claimed"));
        vm.prank(alice);
        game.claimStarterPack();
        assertEq(game.balanceOf(alice, gold), game.STARTER_GOLD());
    }

    function test_MintReward_ByOwner() public {
        vm.expectEmit(true, true, false, true, address(game));
        emit RewardMinted(alice, gold, 50);

        game.mintReward(alice, gold, 50);

        assertEq(game.balanceOf(alice, gold), 50);
    }

    function test_RevertWhen_NonOwnerMints(address caller) public {
        vm.assume(caller != address(this) && caller != address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        game.mintReward(caller, gold, 1);
    }

    function test_RevertWhen_MintUnknownOrSecondSword() public {
        vm.expectRevert(bytes("Unknown item"));
        game.mintReward(alice, 999, 1);

        game.mintReward(alice, sword, 1);
        vm.expectRevert(bytes("Equipment limit"));
        game.mintReward(alice, sword, 1);
        assertEq(game.balanceOf(alice, sword), 1);

        vm.expectRevert(bytes("Equipment amount"));
        game.mintReward(bob, shield, 2);
        assertEq(game.balanceOf(bob, shield), 0);
    }

    function test_BuySword_SpendsGold() public {
        game.mintReward(alice, gold, 150);

        vm.expectEmit(true, true, false, true, address(game));
        emit ItemBought(alice, sword, 1, 100);

        vm.prank(alice);
        game.buyItem(sword, 1);

        assertEq(game.balanceOf(alice, sword), 1);
        assertEq(game.balanceOf(alice, gold), 50);
    }

    function test_RevertWhen_BuyNotForSaleOrAlreadyOwned() public {
        game.mintReward(alice, gold, 500);
        vm.prank(alice);
        game.buyItem(shield, 1);

        vm.expectRevert(bytes("Equipment limit"));
        vm.prank(alice);
        game.buyItem(shield, 1);

        vm.expectRevert(bytes("Not for sale"));
        vm.prank(alice);
        game.buyItem(gold, 1);
        assertEq(game.balanceOf(alice, shield), 1);
        assertEq(game.balanceOf(alice, gold), 420);
    }

    function test_RevertWhen_BuyWithoutEnoughGold() public {
        game.mintReward(alice, gold, 9);
        vm.expectRevert(abi.encodeWithSelector(ERC1155InsufficientBalance.selector, alice, 9, 10, gold));
        vm.prank(alice);
        game.buyItem(potion, 1);
        assertEq(game.balanceOf(alice, potion), 0);
        assertEq(game.balanceOf(alice, gold), 9);
    }

    function testFuzz_BuyPotion_SpendsExactGold(uint96 amount) public {
        amount = uint96(bound(amount, 1, 1000));
        uint256 cost = uint256(amount) * game.POTION_PRICE();
        game.mintReward(alice, gold, cost);

        vm.prank(alice);
        game.buyItem(potion, amount);

        assertEq(game.balanceOf(alice, potion), amount);
        assertEq(game.balanceOf(alice, gold), 0);
    }

    function test_Buy_ReentrancyDoesNotMintTwice() public {
        ReenteringBuyer buyer = new ReenteringBuyer();
        buyer.setGame(game);
        game.mintReward(address(buyer), gold, 100);

        buyer.buyPotion();

        assertEq(game.balanceOf(address(buyer), potion), 1);
        assertEq(game.balanceOf(address(buyer), gold), 90);
    }

    function testFuzz_ExchangeRoundTrip(uint96 goldAmount) public {
        vm.assume(goldAmount != 0);
        game.mintReward(alice, gold, goldAmount);

        vm.startPrank(alice);
        game.exchangeGoldForSilver(goldAmount);
        assertEq(game.balanceOf(alice, silver), uint256(goldAmount) * game.SILVER_PER_GOLD());
        assertEq(game.balanceOf(alice, gold), 0);

        game.exchangeSilverForGold(uint256(goldAmount) * game.SILVER_PER_GOLD());
        vm.stopPrank();

        assertEq(game.balanceOf(alice, gold), goldAmount);
        assertEq(game.balanceOf(alice, silver), 0);
    }

    function test_RevertWhen_SilverRemainderCannotExchange() public {
        game.mintReward(alice, silver, 15);
        vm.expectRevert(bytes("Not a whole gold"));
        vm.prank(alice);
        game.exchangeSilverForGold(15);
        assertEq(game.balanceOf(alice, silver), 15);
        assertEq(game.balanceOf(alice, gold), 0);
    }

    function test_UsePotion_BurnsBalance() public {
        game.mintReward(alice, potion, 3);

        vm.expectEmit(true, false, false, true, address(game));
        emit PotionUsed(alice, 2);

        vm.prank(alice);
        game.usePotion(2);
        assertEq(game.balanceOf(alice, potion), 1);

        vm.expectRevert(bytes("Zero amount"));
        vm.prank(alice);
        game.usePotion(0);

        vm.expectRevert(abi.encodeWithSelector(ERC1155InsufficientBalance.selector, alice, 1, 2, potion));
        vm.prank(alice);
        game.usePotion(2);
        assertEq(game.balanceOf(alice, potion), 1);
    }

    function test_Trade_SwapSwordForShield() public {
        game.mintReward(alice, sword, 1);
        game.mintReward(bob, shield, 1);
        vm.prank(bob);
        game.setApprovalForAll(alice, true);

        vm.expectEmit(true, true, false, true, address(game));
        emit ItemsTraded(alice, bob);

        vm.prank(alice);
        game.tradeItems(alice, bob, _one(sword), _one(1), _one(shield), _one(1));

        assertEq(game.balanceOf(alice, sword), 0);
        assertEq(game.balanceOf(alice, shield), 1);
        assertEq(game.balanceOf(bob, sword), 1);
        assertEq(game.balanceOf(bob, shield), 0);
    }

    /// @notice 两边各有一把剑时，互换完成后每人仍是 1 把，不应被中间余额拦住。
    function test_Trade_SwapIdenticalSwords() public {
        game.mintReward(alice, sword, 1);
        game.mintReward(bob, sword, 1);
        vm.prank(bob);
        game.setApprovalForAll(alice, true);

        vm.prank(alice);
        game.tradeItems(alice, bob, _one(sword), _one(1), _one(sword), _one(1));

        assertEq(game.balanceOf(alice, sword), 1);
        assertEq(game.balanceOf(bob, sword), 1);
    }

    function test_Trade_GiftWithoutRecipientApproval() public {
        game.mintReward(alice, potion, 5);

        vm.prank(alice);
        game.tradeItems(alice, bob, _one(potion), _one(5), new uint256[](0), new uint256[](0));

        assertEq(game.balanceOf(alice, potion), 0);
        assertEq(game.balanceOf(bob, potion), 5);
    }

    function test_Trade_ByOperator() public {
        game.mintReward(alice, gold, 20);
        game.mintReward(bob, potion, 2);
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
        game.mintReward(alice, potion, 1);
        game.mintReward(bob, potion, 1);

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
        game.mintReward(alice, sword, 1);
        game.mintReward(bob, sword, 1);
        vm.prank(bob);
        game.setApprovalForAll(alice, true);

        vm.expectRevert(bytes("Equipment limit"));
        vm.prank(alice);
        game.tradeItems(alice, bob, new uint256[](0), new uint256[](0), _one(sword), _one(1));

        assertEq(game.balanceOf(alice, sword), 1);
        assertEq(game.balanceOf(bob, sword), 1);
    }

    function test_RevertWhen_TradeBundleInvalid() public {
        game.mintReward(alice, potion, 5);
        game.mintReward(bob, potion, 5);
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
        vm.stopPrank();

        assertEq(game.balanceOf(alice, potion), 5);
    }

    function test_RevertWhen_TradeInsufficientBalance() public {
        game.mintReward(bob, potion, 1);
        vm.prank(bob);
        game.setApprovalForAll(alice, true);

        vm.expectRevert(abi.encodeWithSelector(ERC1155InsufficientBalance.selector, alice, 0, 1, potion));
        vm.prank(alice);
        game.tradeItems(alice, bob, _one(potion), _one(1), new uint256[](0), new uint256[](0));
    }

    function _one(uint256 value) private pure returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = value;
    }
}
