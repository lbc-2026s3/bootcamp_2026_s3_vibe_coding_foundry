// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice 演练用 ERC20。`decimals()` 是 18，100 个代币的原始数量是 `100 * 10 ** decimals()`。
///         `mint` 没有权限，只给本地 anvil。
contract LabERC20 is ERC20 {
    constructor() ERC20("Lab Token", "LAB") {}

    /// @notice 给 to 铸造 amount 个最小单位。
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice 演练用 ERC721。tokenId 从 1 开始递增。
contract LabNFT is ERC721 {
    uint256 public nextId = 1;

    constructor() ERC721("Lab NFT", "LNFT") {}

    /// @notice 给 to 铸造一枚 NFT，返回 tokenId。
    function mint(address to) external returns (uint256 tokenId) {
        tokenId = nextId;
        nextId = tokenId + 1;
        _mint(to, tokenId);
    }
}
