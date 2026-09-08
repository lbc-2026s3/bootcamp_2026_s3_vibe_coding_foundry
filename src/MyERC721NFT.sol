// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC721URIStorage, ERC721} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/// @notice MyERC721NFT: 基于 OpenZeppelin ERC721URIStorage，支持按 tokenURI 铸造 NFT
contract MyERC721NFT is ERC721URIStorage {
    uint256 private _nextTokenId;

    constructor() ERC721("MyERC721NFT", "MNFT") {}

    /// @notice 为 `to` 铸造一枚 NFT，并绑定 `uri`（如 ipfs://...）
    /// @return tokenId 新铸造的 tokenId（从 0 递增）
    function mint(address to, string memory uri) public returns (uint256) {
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
}
