// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Pausable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AdvancedMultiToken
/// @notice 多种类 ERC1155。owner 创建代币 id，owner 和 minter 可以铸造。
/// 全局 pause 会停掉铸造、销毁和转账；单个 id 的 isPaused 只停该 id 的铸造。
/// maxSupply 为 0 表示这个 id 还没创建，因此创建时 maxSupply 必须大于 0。
contract AdvancedMultiToken is ERC1155Pausable, Ownable, ReentrancyGuard {
    /// @notice 某个代币 id 的元数据和供应量。
    struct TokenInfo {
        string name;
        string symbol;
        uint256 maxSupply;
        uint256 currentSupply;
        bool isFungible; // 同质化/非同质化代币
        bool isPaused;
    }

    /// @notice id 对应的元数据。maxSupply 为 0 表示尚未创建。
    mapping(uint256 id => TokenInfo) public tokenInfo;
    /// @notice id 对应的 metadata URI。
    mapping(uint256 id => string) private _tokenURIs;
    /// @notice 除 owner 之外、可以铸造的地址。
    mapping(address account => bool) public minters;

    /// @notice 新的代币 id 已创建。
    event TokenCreated(uint256 indexed id, string name, string symbol, bool isFungible);
    /// @notice 代币已铸造。
    event TokenMinted(uint256 indexed id, address indexed to, uint256 amount);
    /// @notice 代币已销毁。
    event TokenBurned(uint256 indexed id, address indexed from, uint256 amount);

    /// @notice 部署者成为 owner。基础 URI 为空，每个 id 用自己的 URI。
    constructor() ERC1155("") Ownable(msg.sender) {}

    /// @notice 只有 owner，或被 setMinter 设为 true 的地址可以铸造。
    modifier onlyMinter() {
        require(minters[msg.sender] || msg.sender == owner(), "Not a minter");
        _;
    }

    /// @notice 创建一个新的代币 id。同一个 id 不能创建两次。
    function createToken(
        uint256 id,
        string calldata name,
        string calldata symbol,
        uint256 maxSupply,
        bool isFungible,
        string calldata tokenURI
    ) external onlyOwner {
        require(tokenInfo[id].maxSupply == 0, "Token already exists");
        require(maxSupply > 0, "Max supply is zero");

        tokenInfo[id] = TokenInfo({
            name: name, symbol: symbol, maxSupply: maxSupply, currentSupply: 0, isFungible: isFungible, isPaused: false
        });
        _tokenURIs[id] = tokenURI;

        emit TokenCreated(id, name, symbol, isFungible);
        emit URI(tokenURI, id);
    }

    /// @notice 铸造已创建的代币。先记账再铸，避免接收合约回调时供应量对不上。
    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external onlyMinter nonReentrant {
        _accountMint(id, amount);
        _mint(to, id, amount, data);
        emit TokenMinted(id, to, amount);
    }

    /// @notice 批量铸造。ids 和 amounts 必须等长，同一个 id 可以出现多次。
    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data)
        external
        onlyMinter
        nonReentrant
    {
        require(ids.length == amounts.length, "Arrays length mismatch");
        for (uint256 i = 0; i < ids.length; ++i) {
            _accountMint(ids[i], amounts[i]);
        }
        _mintBatch(to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; ++i) {
            emit TokenMinted(ids[i], to, amounts[i]);
        }
    }

    /// @notice 销毁自己的代币，或销毁已授权 operator 的代币。
    function burn(address from, uint256 id, uint256 amount) external {
        _checkBurner(from);
        _requireToken(id);
        _burn(from, id, amount);
        tokenInfo[id].currentSupply -= amount;
        emit TokenBurned(id, from, amount);
    }

    /// @notice 批量销毁。先烧掉再减供应量，余额不够时沿用 ERC1155 的错误。
    function burnBatch(address from, uint256[] calldata ids, uint256[] calldata amounts) external {
        _checkBurner(from);
        require(ids.length == amounts.length, "Arrays length mismatch");
        for (uint256 i = 0; i < ids.length; ++i) {
            _requireToken(ids[i]);
        }
        _burnBatch(from, ids, amounts);
        for (uint256 i = 0; i < ids.length; ++i) {
            tokenInfo[ids[i]].currentSupply -= amounts[i];
            emit TokenBurned(ids[i], from, amounts[i]);
        }
    }

    /// @notice 更新某个已创建 id 的 URI。
    function setURI(uint256 id, string calldata tokenURI) external onlyOwner {
        _requireToken(id);
        _tokenURIs[id] = tokenURI;
        emit URI(tokenURI, id);
    }

    /// @notice 返回这个 id 自己的 URI，不使用全局 URI 模板。
    function uri(uint256 id) public view override returns (string memory) {
        return _tokenURIs[id];
    }

    /// @notice 暂停全部铸造、销毁和转账。
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice 恢复全部铸造、销毁和转账。
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice 暂停某个 id 的铸造。转账和销毁不受影响。
    function pauseToken(uint256 id) external onlyOwner {
        _requireToken(id);
        tokenInfo[id].isPaused = true;
    }

    /// @notice 恢复某个 id 的铸造。
    function unpauseToken(uint256 id) external onlyOwner {
        _requireToken(id);
        tokenInfo[id].isPaused = false;
    }

    /// @notice 授予或收回铸造权限。owner 不在这个名单里也能铸造。
    function setMinter(address minter, bool status) external onlyOwner {
        minters[minter] = status;
    }

    /// @dev 检查 id 已创建，并且这次铸造不会超过 maxSupply，然后增加 currentSupply。
    function _accountMint(uint256 id, uint256 amount) private {
        TokenInfo storage info = tokenInfo[id];
        require(info.maxSupply != 0, "Token does not exist");
        require(!info.isPaused, "Token minting paused");
        // 用剩余额度比较，避免 currentSupply + amount 溢出时变成算术 panic。
        require(amount <= info.maxSupply - info.currentSupply, "Exceeds max supply");
        info.currentSupply += amount;
    }

    function _requireToken(uint256 id) private view {
        require(tokenInfo[id].maxSupply != 0, "Token does not exist");
    }

    function _checkBurner(address from) private view {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "Not authorized");
    }
}
