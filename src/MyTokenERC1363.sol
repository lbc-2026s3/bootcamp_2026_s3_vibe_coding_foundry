// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC1363} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC1363.sol";

/// @notice MyTokenERC1363:固定供应量 ERC-1363 token,部署时铸造 100 万枚给部署者
contract MyTokenERC1363 is ERC1363 {
    /// @notice 初始供应量:100 万枚(18 位小数)
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    constructor() ERC20("MyToken1363", "MT1363") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
