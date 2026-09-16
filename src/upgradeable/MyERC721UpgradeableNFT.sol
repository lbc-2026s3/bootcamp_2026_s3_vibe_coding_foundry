// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC721URIStorageUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @notice MyERC721UpgradeableNFT: UUPS 可升级 ERC721，按 tokenURI 铸造，与 MyERC721NFT 行为对齐
contract MyERC721UpgradeableNFT is
    Initializable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    uint256 internal _nextTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice 通过代理初始化 name/symbol，并将升级权交给 `initialOwner`
    function initialize(address initialOwner) public initializer {
        __ERC721_init("MyERC721UpgradeableNFT", "UNFT");
        __ERC721URIStorage_init();
        __Ownable_init(initialOwner);
    }

    /// @notice 为 `to` 铸造一枚 NFT，并绑定 `uri`（如 ipfs://...）
    /// @return tokenId 新铸造的 tokenId（从 0 递增）
    function mint(address to, string memory uri) public virtual returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        // OZ 5.x 允许 mint 前设置 URI，保证 onERC721Received 回调可读到正确 metadata
        _setTokenURI(tokenId, uri);
        _safeMint(to, tokenId);
        return tokenId;
    }

    /// @notice 下一枚将铸造的 tokenId
    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
