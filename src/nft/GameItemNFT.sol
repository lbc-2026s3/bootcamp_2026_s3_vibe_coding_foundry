// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title GameItemNFT — 带耐久和装备状态的游戏道具 ERC721
/// @notice 只有 owner 能铸造。道具跟着 token 走：转账会改持有者列表，并卸下已装备的道具。
/// @dev `playerItems` 在 {_update} 里维护。销毁（`to == address(0)`）会从列表和计数里拿掉这件道具。
contract GameItemNFT is ERC721URIStorage, Ownable {
    struct GameItem {
        string name;
        string itemType;
        uint256 level;
        uint256 attack;
        uint256 defense;
        uint256 durability;
        uint256 maxDurability;
        bool isEquipped;
    }

    mapping(uint256 tokenId => GameItem) public gameItems;
    mapping(address player => uint256[] tokenIds) public playerItems;
    /// @notice 当前还存在的该类型道具数量。转账不变，销毁才减。
    mapping(string itemType => uint256) public itemTypeCount;
    /// @notice 当前还存在的道具数量，不是历史铸造次数。
    uint256 public totalItems;

    /// @dev tokenId 在当前持有者 `playerItems` 数组里的下标，用来 O(1) 删除。
    mapping(uint256 tokenId => uint256) private _heldIndex;

    event ItemCreated(uint256 indexed tokenId, address indexed player, string name, string itemType, uint256 level);
    event ItemEquipped(uint256 indexed tokenId, address indexed player);
    event ItemUnequipped(uint256 indexed tokenId, address indexed player);
    event ItemUsed(uint256 indexed tokenId, address indexed player, uint256 durability);
    event ItemRepaired(uint256 indexed tokenId, uint256 newDurability);

    error EmptyName();
    error EmptyItemType();
    error ZeroDurability();
    error NotItemOwner(address account, uint256 tokenId);
    error AlreadyEquipped(uint256 tokenId);
    error NotEquipped(uint256 tokenId);
    error ItemBroken(uint256 tokenId);
    error AlreadyAtMaxDurability(uint256 tokenId);

    constructor() ERC721("Game Items", "GAME") Ownable(msg.sender) {}

    /// @notice 给 `to` 铸造一件道具。`tokenId` 由调用方指定，不能和现存 token 重复。
    /// @dev 属性先写上，再 `_safeMint`。接收方若是合约，回调时已经能读到属性和 URI。
    function createItem(
        address to,
        uint256 tokenId,
        string memory name,
        string memory itemType,
        uint256 level,
        uint256 attack,
        uint256 defense,
        uint256 durability,
        string memory tokenURI_
    ) external onlyOwner {
        if (bytes(name).length == 0) revert EmptyName();
        if (bytes(itemType).length == 0) revert EmptyItemType();
        if (durability == 0) revert ZeroDurability();

        gameItems[tokenId] = GameItem({
            name: name,
            itemType: itemType,
            level: level,
            attack: attack,
            defense: defense,
            durability: durability,
            maxDurability: durability,
            isEquipped: false
        });
        itemTypeCount[itemType] += 1;
        totalItems += 1;

        _setTokenURI(tokenId, tokenURI_);
        _safeMint(to, tokenId);

        emit ItemCreated(tokenId, to, name, itemType, level);
    }

    /// @notice 装备自己持有、尚未装备、且耐久大于 0 的道具。
    function equipItem(uint256 tokenId) external {
        _checkOwner(tokenId);
        GameItem storage item = gameItems[tokenId];
        if (item.isEquipped) revert AlreadyEquipped(tokenId);
        if (item.durability == 0) revert ItemBroken(tokenId);

        item.isEquipped = true;
        emit ItemEquipped(tokenId, msg.sender);
    }

    /// @notice 卸下自己已装备的道具。
    function unequipItem(uint256 tokenId) external {
        _checkOwner(tokenId);
        if (!gameItems[tokenId].isEquipped) revert NotEquipped(tokenId);

        gameItems[tokenId].isEquipped = false;
        emit ItemUnequipped(tokenId, msg.sender);
    }

    /// @notice 使用道具，耐久减 1。耐久归零时如果正装备着，会自动卸下。
    function useItem(uint256 tokenId) external {
        _checkOwner(tokenId);
        GameItem storage item = gameItems[tokenId];
        if (item.durability == 0) revert ItemBroken(tokenId);

        item.durability -= 1;
        emit ItemUsed(tokenId, msg.sender, item.durability);

        if (item.durability == 0 && item.isEquipped) {
            item.isEquipped = false;
            emit ItemUnequipped(tokenId, msg.sender);
        }
    }

    /// @notice 把耐久补回上限。不会自动重新装备。
    function repairItem(uint256 tokenId) external {
        _checkOwner(tokenId);
        GameItem storage item = gameItems[tokenId];
        if (item.durability >= item.maxDurability) revert AlreadyAtMaxDurability(tokenId);

        item.durability = item.maxDurability;
        emit ItemRepaired(tokenId, item.maxDurability);
    }

    /// @notice 返回某地址当前持有的道具 id。转账后旧地址不再包含已转出的 id。
    function getPlayerItems(address player) external view returns (uint256[] memory) {
        return playerItems[player];
    }

    /// @notice 返回道具属性。不存在的 token 会 revert。
    function getItemStats(uint256 tokenId)
        external
        view
        returns (
            string memory name,
            string memory itemType,
            uint256 level,
            uint256 attack,
            uint256 defense,
            uint256 durability,
            uint256 maxDurability
        )
    {
        _requireOwned(tokenId);
        GameItem memory item = gameItems[tokenId];
        return (item.name, item.itemType, item.level, item.attack, item.defense, item.durability, item.maxDurability);
    }

    /// @dev 铸造、转账、销毁都走这里，保证 `playerItems` 和装备状态跟所有权一致。
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = super._update(to, tokenId, auth);
        if (from == to) return from;

        if (from != address(0)) {
            _removeFromPlayer(from, tokenId);
            if (gameItems[tokenId].isEquipped) {
                gameItems[tokenId].isEquipped = false;
                emit ItemUnequipped(tokenId, from);
            }
        }

        if (to == address(0)) {
            string memory itemType = gameItems[tokenId].itemType;
            if (itemTypeCount[itemType] > 0) itemTypeCount[itemType] -= 1;
            if (totalItems > 0) totalItems -= 1;
            delete gameItems[tokenId];
        } else {
            _addToPlayer(to, tokenId);
        }

        return from;
    }

    function _checkOwner(uint256 tokenId) private view {
        address owner = ownerOf(tokenId);
        if (owner != msg.sender) revert NotItemOwner(msg.sender, tokenId);
    }

    function _addToPlayer(address player, uint256 tokenId) private {
        _heldIndex[tokenId] = playerItems[player].length;
        playerItems[player].push(tokenId);
    }

    function _removeFromPlayer(address player, uint256 tokenId) private {
        uint256[] storage items = playerItems[player];
        uint256 index = _heldIndex[tokenId];
        uint256 lastIndex = items.length - 1;

        if (index != lastIndex) {
            uint256 lastId = items[lastIndex];
            items[index] = lastId;
            _heldIndex[lastId] = index;
        }

        items.pop();
        delete _heldIndex[tokenId];
    }
}
