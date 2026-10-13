// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title GameEconomy
/// @notice 一种 ERC1155 同时管理游戏货币和道具。
/// 金币、银币、药水可以叠加；剑和盾每个地址最多持有 1 件。
/// 玩家先领新手包，再用金币购买，也可以和另一个玩家互换。
contract GameEconomy is ERC1155, Ownable, ReentrancyGuard {
    // 代币 ID
    uint256 public constant GOLD_COIN = 1; // 可叠加 - 游戏货币(金币)
    uint256 public constant SILVER_COIN = 2; // 可叠加 - 游戏货币(银币)
    uint256 public constant SWORD = 1001; // 不可叠加 - 武器(剑)
    uint256 public constant SHIELD = 1002; // 不可叠加 - 防具
    uint256 public constant POTION = 2001; // 可叠加 - 消耗品(药水)

    /// @notice 1 枚金币兑换的银币数量。
    uint256 public constant SILVER_PER_GOLD = 10; // 1 金币兑换 10 银币
    /// @notice 商店标价，单位是金币。
    uint256 public constant SWORD_PRICE = 100; // 剑 100 金币
    uint256 public constant SHIELD_PRICE = 80; // 盾 80 金币
    uint256 public constant POTION_PRICE = 10; // 药水 10 金币
    /// @notice 新手包内容。claimStarterPack 铸给调用者，每个地址只能领一次。
    uint256 public constant STARTER_GOLD = 200; // 新手包：200 金币
    uint256 public constant STARTER_POTION = 2; // 新手包：2 瓶药水

    /// @notice 是否已经领过新手包。
    mapping(address player => bool claimed) public starterClaimed;

    /// @notice 新手包已领取。
    event StarterClaimed(address indexed player);
    /// @notice 游戏方发放了奖励。
    event RewardMinted(address indexed to, uint256 indexed id, uint256 amount);
    /// @notice 玩家用金币买了道具。
    event ItemBought(address indexed buyer, uint256 indexed id, uint256 amount, uint256 goldSpent);
    /// @notice 金币换成了银币。
    event GoldExchanged(address indexed account, uint256 goldIn, uint256 silverOut);
    /// @notice 银币换成了金币。
    event SilverExchanged(address indexed account, uint256 silverIn, uint256 goldOut);
    /// @notice 药水已使用并销毁。
    event PotionUsed(address indexed account, uint256 amount);
    /// @notice 两名玩家完成互换。Transfer 事件里有具体的 id 和数量。
    event ItemsTraded(address indexed from, address indexed to);

    /// @notice 部署者是游戏方，可以发放奖励。
    constructor() ERC1155("https://example.com/game/{id}.json") Ownable(msg.sender) {}

    /// @notice 金币、银币、药水可以叠加。剑和盾不行。
    function isFungible(uint256 id) public pure returns (bool) {
        return id == GOLD_COIN || id == SILVER_COIN || id == POTION;
    }

    /// @notice 商店售价。金币和银币不卖，返回 0。
    function priceOf(uint256 id) public pure returns (uint256) {
        if (id == SWORD) return SWORD_PRICE;
        if (id == SHIELD) return SHIELD_PRICE;
        if (id == POTION) return POTION_PRICE;
        return 0;
    }

    /// @notice 领取新手包：200 金币和 2 瓶药水。每个地址一次。
    function claimStarterPack() external nonReentrant {
        require(!starterClaimed[msg.sender], "Already claimed");
        starterClaimed[msg.sender] = true;

        _mint(msg.sender, GOLD_COIN, STARTER_GOLD, "");
        _mint(msg.sender, POTION, STARTER_POTION, "");
        emit StarterClaimed(msg.sender);
    }

    /// @notice 游戏方给玩家发放一种奖励。
    function mintReward(address to, uint256 id, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Zero address");
        _requireMintable(to, id, amount);
        _mint(to, id, amount, "");
        emit RewardMinted(to, id, amount);
    }

    /// @notice 用金币购买剑、盾或药水。装备已经持有时不能再买。
    function buyItem(uint256 id, uint256 amount) external nonReentrant {
        uint256 price = priceOf(id);
        require(price != 0, "Not for sale");
        _requireMintable(msg.sender, id, amount);

        uint256 cost = price * amount;
        _burn(msg.sender, GOLD_COIN, cost);
        _mint(msg.sender, id, amount, "");
        emit ItemBought(msg.sender, id, amount, cost);
    }

    /// @notice 按 1:10 把金币换成银币。
    function exchangeGoldForSilver(uint256 goldAmount) external nonReentrant {
        require(goldAmount != 0, "Zero amount");
        uint256 silverOut = goldAmount * SILVER_PER_GOLD;
        _burn(msg.sender, GOLD_COIN, goldAmount);
        _mint(msg.sender, SILVER_COIN, silverOut, "");
        emit GoldExchanged(msg.sender, goldAmount, silverOut);
    }

    /// @notice 按 10:1 把银币换成金币。不足 10 的零头不能兑换。
    function exchangeSilverForGold(uint256 silverAmount) external nonReentrant {
        require(silverAmount != 0, "Zero amount");
        require(silverAmount % SILVER_PER_GOLD == 0, "Not a whole gold");
        uint256 goldOut = silverAmount / SILVER_PER_GOLD;
        _burn(msg.sender, SILVER_COIN, silverAmount);
        _mint(msg.sender, GOLD_COIN, goldOut, "");
        emit SilverExchanged(msg.sender, silverAmount, goldOut);
    }

    /// @notice 使用药水。药水被销毁，不换成别的资产。
    function usePotion(uint256 amount) external {
        require(amount != 0, "Zero amount");
        _burn(msg.sender, POTION, amount);
        emit PotionUsed(msg.sender, amount);
    }

    /// @notice 双方互换物品。
    /// 只检查资产被转出的那一方：调用者是本人，或已被 setApprovalForAll。
    /// 只送出自己的道具时，接收方不用授权。要取走对方道具时，对方需先授权调用者。
    /// 授权期间调用者可以转走对方的任意道具，交易后应取消授权。
    /// 剑和盾按互换完成后的余额检查，所以两把剑可以直接对调。
    function tradeItems(
        address from,
        address to,
        uint256[] calldata giveIds,
        uint256[] calldata giveAmounts,
        uint256[] calldata takeIds,
        uint256[] calldata takeAmounts
    ) external nonReentrant {
        require(from != address(0) && to != address(0), "Zero address");
        require(from != to, "Same address");
        require(giveIds.length != 0 || takeIds.length != 0, "Empty trade");
        if (giveIds.length != 0) _checkOperator(from);
        if (takeIds.length != 0) _checkOperator(to);
        _validateBundle(giveIds, giveAmounts);
        _validateBundle(takeIds, takeAmounts);
        // from 给出 give、获得 take；to 相反。先算完再转，避免对调装备时中间余额超限。
        _checkEquipment(from, takeIds, takeAmounts, giveIds, giveAmounts);
        _checkEquipment(to, giveIds, giveAmounts, takeIds, takeAmounts);

        if (giveIds.length != 0) {
            _safeBatchTransferFrom(from, to, giveIds, giveAmounts, "");
        }
        if (takeIds.length != 0) {
            _safeBatchTransferFrom(to, from, takeIds, takeAmounts, "");
        }
        emit ItemsTraded(from, to);
    }

    /// @dev 已知的 id 才能铸造。装备数量必须是 1，且接收者还没有。
    function _requireMintable(address to, uint256 id, uint256 amount) private view {
        require(_isKnown(id), "Unknown item");
        require(amount != 0, "Zero amount");
        if (!isFungible(id)) {
            require(amount == 1, "Equipment amount");
            require(balanceOf(to, id) == 0, "Equipment limit");
        }
    }

    function _isKnown(uint256 id) private pure returns (bool) {
        return id == GOLD_COIN || id == SILVER_COIN || id == SWORD || id == SHIELD || id == POTION;
    }

    /// @dev 调用者是账户本人，或已被该账户设为 operator。
    function _checkOperator(address account) private view {
        require(msg.sender == account || isApprovedForAll(account, msg.sender), "Not authorized");
    }

    function _validateBundle(uint256[] calldata ids, uint256[] calldata amounts) private pure {
        require(ids.length == amounts.length, "Arrays length mismatch");
        for (uint256 i = 0; i < ids.length; ++i) {
            require(_isKnown(ids[i]), "Unknown item");
            require(amounts[i] != 0, "Zero amount");
            if (!isFungible(ids[i])) {
                require(amounts[i] == 1, "Equipment amount");
            }
            for (uint256 j = 0; j < i; ++j) {
                require(ids[j] != ids[i], "Duplicate id");
            }
        }
    }

    /// @dev incoming 是这次会收到的，outgoing 是这次会给出的。只限制剑和盾。
    function _checkEquipment(
        address account,
        uint256[] calldata incomingIds,
        uint256[] calldata incomingAmounts,
        uint256[] calldata outgoingIds,
        uint256[] calldata outgoingAmounts
    ) private view {
        _checkOneEquipment(
            account,
            SWORD,
            _amountOf(SWORD, incomingIds, incomingAmounts),
            _amountOf(SWORD, outgoingIds, outgoingAmounts)
        );
        _checkOneEquipment(
            account,
            SHIELD,
            _amountOf(SHIELD, incomingIds, incomingAmounts),
            _amountOf(SHIELD, outgoingIds, outgoingAmounts)
        );
    }

    function _checkOneEquipment(address account, uint256 id, uint256 incoming, uint256 outgoing) private view {
        if (incoming == 0 && outgoing == 0) return;
        uint256 balance = balanceOf(account, id);
        // 余额不够时留给转账去报 ERC1155 的错误，这里避免下溢。
        if (outgoing > balance) return;
        require(balance - outgoing + incoming <= 1, "Equipment limit");
    }

    function _amountOf(uint256 id, uint256[] calldata ids, uint256[] calldata amounts) private pure returns (uint256) {
        for (uint256 i = 0; i < ids.length; ++i) {
            if (ids[i] == id) return amounts[i];
        }
        return 0;
    }
}
