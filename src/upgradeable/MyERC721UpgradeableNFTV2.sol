// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyERC721UpgradeableNFT} from "./MyERC721UpgradeableNFT.sol";

/// @notice V2：在 V1 存储末尾追加 `totalSupply`（不得插入/重排 V1 变量）
/// @custom:oz-upgrades-from MyERC721UpgradeableNFT
contract MyERC721UpgradeableNFTV2 is MyERC721UpgradeableNFT {
    uint256 public totalSupply;

    /// @notice 按升级前状态初始化：tokenId 从 0 递增且无 burn，`_nextTokenId` 即已发行量
    function initializeV2() public reinitializer(2) onlyOwner {
        totalSupply = _nextTokenId;
    }

    function mint(address to, string memory uri) public override returns (uint256) {
        uint256 tokenId = super.mint(to, uri);
        unchecked {
            ++totalSupply;
        }
        return tokenId;
    }
}
