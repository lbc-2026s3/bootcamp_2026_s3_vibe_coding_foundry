// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC721A} from "erc721a/ERC721A.sol";

/// @notice MyERC721ANFT: 基于 Chiru Labs ERC721A，一次交易可批量铸造，gas 显著低于逐枚 mint
contract MyERC721ANFT is ERC721A {
    /// @notice 单次 mint 数量上限。ERC721A 只在批次首个 tokenId 写入 ownership，
    ///         过大的 quantity 会让后续 transfer 回溯 SLOAD 过多而 OOG。
    uint256 public constant MAX_MINT_QUANTITY = 20;

    error ExceedsMaxMintQuantity();

    /// @dev 集合级 metadata（如 ipfs://Qm... JSON），所有 token 共用
    string private _collectionURI;

    constructor(string memory collectionURI_) ERC721A("MyERC721ANFT", "ANFT") {
        _collectionURI = collectionURI_;
    }

    /// @notice 为 `to` 铸造 `quantity` 枚连续 tokenId 的 NFT（须 > 0 且 ≤ MAX_MINT_QUANTITY）
    function mint(address to, uint256 quantity) public {
        if (quantity > MAX_MINT_QUANTITY) revert ExceedsMaxMintQuantity();
        _safeMint(to, quantity);
    }

    /// @notice 下一枚将铸造的 tokenId
    function nextTokenId() external view returns (uint256) {
        return _nextTokenId();
    }

    /// @notice 集合 metadata URI；所有已铸造 token 的 `tokenURI` 都返回该值
    function collectionURI() external view returns (string memory) {
        return _collectionURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        return _collectionURI;
    }
}
