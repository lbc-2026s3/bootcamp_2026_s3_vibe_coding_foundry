// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {ERC1155Utils} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Utils.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title GameEconomy2
/// @notice 一种 ERC1155 同时管理游戏货币和道具。
/// 金币、银币、铜币、药水、卷轴可以叠加；剑和盾每个地址最多持有 1 件。
/// 游戏方先登记道具再铸造。玩家可以互换，也可以使用药水和卷轴。
contract GameEconomy2 is ERC1155URIStorage, ERC1155Supply, Ownable, ReentrancyGuard {
    uint256 public constant GOLD_COIN = 1; // 金币
    uint256 public constant SILVER_COIN = 2; // 银币
    uint256 public constant COPPER_COIN = 3; // 铜币
    uint256 public constant SWORD = 1001; // 剑
    uint256 public constant SHIELD = 1002; // 盾
    uint256 public constant POTION = 2001; // 药水
    uint256 public constant SCROLL = 2002; // 卷轴

    struct ItemInfo {
        string name;      // 道具展示名
        string itemType;  // 道具类型
        uint256 level;    // 道具等级
        uint256 attack;   // 道具攻击力
        uint256 defense;  // 道具防御力
        bool isFungible;  // 是否可叠加
        uint256 maxSupply; // 最大供应量
    }

    /// @notice 道具参数。maxSupply 为 0 表示还没登记。
    mapping(uint256 id => ItemInfo) public itemInfo;
    /// @notice 消耗品累计效果。药水 id 记生命，卷轴 id 记魔法。
    mapping(address account => mapping(uint256 id => uint256 bonus)) public playerStats;
    /// @notice 玩家接触过的道具 id。余额为 0 的 id 仍可能留在这里，读取请用 getPlayerInventory。
    mapping(address account => uint256[] ids) public playerInventory;

    mapping(address account => mapping(uint256 id => bool seen)) private _tracked;
    mapping(address account => uint256) private _attack;
    mapping(address account => uint256) private _defense;
    /// @dev 互换的两笔记账之间暂时跳过单笔装备检查，避免两把剑对调时中间余额超限。
    bool private _skipEquipmentCheck;

    event ItemCreated(uint256 indexed id, string name, string itemType, bool isFungible);
    event ItemTraded(address indexed from, address indexed to, uint256[] ids, uint256[] amounts);
    event StatsUpdated(address indexed player, uint256 attack, uint256 defense);

    /// @notice 部署者是游戏方，可以登记和铸造道具。
    constructor() ERC1155("") Ownable(msg.sender) {}

    /// @notice 单个道具的元数据。没单独设置时返回空字符串。
    function uri(uint256 tokenId) public view override(ERC1155, ERC1155URIStorage) returns (string memory) {
        return ERC1155URIStorage.uri(tokenId);
    }

    /// @notice 登记一种道具。同一个 id 只能登记一次，maxSupply 必须大于 0。
    function createItem(
        uint256 id,
        string memory name,
        string memory itemType,
        uint256 level,
        uint256 attack,
        uint256 defense,
        bool isFungible,
        uint256 maxSupply,
        string memory tokenURI
    ) external onlyOwner {
        require(itemInfo[id].maxSupply == 0, "Item already exists");
        require(maxSupply != 0, "Zero max supply");
        itemInfo[id] = ItemInfo({
            name: name,
            itemType: itemType,
            level: level,
            attack: attack,
            defense: defense,
            isFungible: isFungible,
            maxSupply: maxSupply
        });
        _setURI(id, tokenURI);
        emit ItemCreated(id, name, itemType, isFungible);
    }

    /// @notice 游戏方铸造已登记的道具。不可叠加道具每次只能铸 1 件，且接收者还没有。
    function mintItem(address to, uint256 id, uint256 amount) external onlyOwner nonReentrant {
        require(itemInfo[id].maxSupply > 0, "Item does not exist");
        require(amount != 0, "Zero amount");
        require(totalSupply(id) + amount <= itemInfo[id].maxSupply, "Exceeds max supply");
        _mint(to, id, amount, "");
    }

    /// @notice 双方互换物品。
    /// 只检查资产被转出的那一方：调用者是本人，或已被 setApprovalForAll。
    /// 只送出自己的道具时，接收方不用授权。要取走对方道具时，对方需先授权调用者。
    /// 剑和盾按互换完成后的余额检查，所以两件同类装备可以直接对调。
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

        _skipEquipmentCheck = true;
        if (giveIds.length != 0) _update(from, to, giveIds, giveAmounts);
        if (takeIds.length != 0) _update(to, from, takeIds, takeAmounts);
        _skipEquipmentCheck = false;

        // 两边余额已经落定，再通知接收方，回调里不能绕过装备上限。
        if (giveIds.length != 0) _accept(from, to, giveIds, giveAmounts);
        if (takeIds.length != 0) _accept(to, from, takeIds, takeAmounts);
        emit ItemTraded(from, to, giveIds, giveAmounts);
    }

    /// @notice 使用药水或卷轴。代币被销毁，效果累加到 playerStats。
    function useConsumable(uint256 id, uint256 amount) external {
        require(amount != 0, "Zero amount");
        require(itemInfo[id].maxSupply > 0, "Item does not exist");
        require(itemInfo[id].isFungible, "Not a consumable");
        require(id == POTION || id == SCROLL, "Not a consumable");
        _burn(msg.sender, id, amount);
        if (id == POTION) {
            playerStats[msg.sender][id] += amount * 10;
        } else {
            playerStats[msg.sender][id] += amount * 5;
        }
    }

    /// @notice 当前装备带来的攻击和防御。消耗品效果在 playerStats 里。
    function getPlayerStats(address player) external view returns (uint256 attack, uint256 defense) {
        return (_attack[player], _defense[player]);
    }

    /// @notice 余额大于 0 的道具 id。
    function getPlayerInventory(address player) external view returns (uint256[] memory) {
        uint256[] storage raw = playerInventory[player];
        uint256 count;
        for (uint256 i = 0; i < raw.length; ++i) {
            if (balanceOf(player, raw[i]) > 0) ++count;
        }
        uint256[] memory ids = new uint256[](count);
        uint256 n;
        for (uint256 i = 0; i < raw.length; ++i) {
            uint256 id = raw[i];
            if (balanceOf(player, id) > 0) {
                ids[n++] = id;
            }
        }
        return ids;
    }

    /// @dev 普通转账和铸造都走这里。互换的两笔记账会暂时跳过，因为净额已经检查过。
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        if (!_skipEquipmentCheck && to != address(0)) {
            _enforceEquipment(to, ids, values);
        }
        super._update(from, to, ids, values);
        if (from != address(0)) {
            _remember(from, ids);
            _refreshCombat(from);
        }
        if (to != address(0)) {
            _remember(to, ids);
            _refreshCombat(to);
        }
    }

    function _enforceEquipment(address to, uint256[] memory ids, uint256[] memory values) private view {
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            if (itemInfo[id].maxSupply == 0 || itemInfo[id].isFungible) continue;
            require(values[i] == 1, "Equipment amount");
            require(balanceOf(to, id) == 0, "Equipment limit");
        }
    }

    function _checkOperator(address account) private view {
        require(msg.sender == account || isApprovedForAll(account, msg.sender), "Not authorized");
    }

    function _validateBundle(uint256[] calldata ids, uint256[] calldata amounts) private view {
        require(ids.length == amounts.length, "Arrays length mismatch");
        for (uint256 i = 0; i < ids.length; ++i) {
            require(itemInfo[ids[i]].maxSupply > 0, "Unknown item");
            require(amounts[i] != 0, "Zero amount");
            if (!itemInfo[ids[i]].isFungible) {
                require(amounts[i] == 1, "Equipment amount");
            }
            for (uint256 j = 0; j < i; ++j) {
                require(ids[j] != ids[i], "Duplicate id");
            }
        }
    }

    /// @dev incoming 是这次会收到的，outgoing 是这次会给出的。只限制不可叠加道具。
    function _checkEquipment(
        address account,
        uint256[] calldata incomingIds,
        uint256[] calldata incomingAmounts,
        uint256[] calldata outgoingIds,
        uint256[] calldata outgoingAmounts
    ) private view {
        for (uint256 i = 0; i < incomingIds.length; ++i) {
            uint256 id = incomingIds[i];
            if (itemInfo[id].isFungible) continue;
            uint256 outgoing = _amountOf(id, outgoingIds, outgoingAmounts);
            uint256 balance = balanceOf(account, id);
            // 余额不够时留给转账去报 ERC1155 的错误，这里避免下溢。
            if (outgoing > balance) continue;
            require(balance - outgoing + incomingAmounts[i] <= 1, "Equipment limit");
        }
    }

    function _amountOf(uint256 id, uint256[] calldata ids, uint256[] calldata amounts) private pure returns (uint256) {
        for (uint256 i = 0; i < ids.length; ++i) {
            if (ids[i] == id) return amounts[i];
        }
        return 0;
    }

    function _accept(address from, address to, uint256[] calldata ids, uint256[] calldata amounts) private {
        if (ids.length == 1) {
            ERC1155Utils.checkOnERC1155Received(msg.sender, from, to, ids[0], amounts[0], "");
        } else {
            ERC1155Utils.checkOnERC1155BatchReceived(msg.sender, from, to, ids, amounts, "");
        }
    }

    function _remember(address account, uint256[] memory ids) private {
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            if (_tracked[account][id]) continue;
            _tracked[account][id] = true;
            playerInventory[account].push(id);
        }
    }

    /// @dev 不可叠加且仍持有的道具各贡献一次攻击和防御。
    function _refreshCombat(address player) private {
        uint256 totalAttack;
        uint256 totalDefense;
        uint256[] storage ids = playerInventory[player];
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            if (balanceOf(player, id) == 0 || itemInfo[id].isFungible) continue;
            totalAttack += itemInfo[id].attack;
            totalDefense += itemInfo[id].defense;
        }
        if (_attack[player] == totalAttack && _defense[player] == totalDefense) return;
        _attack[player] = totalAttack;
        _defense[player] = totalDefense;
        emit StatsUpdated(player, totalAttack, totalDefense);
    }
}
