// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @notice MyTokenV1:基于 OpenZeppelin ERC20,部署时一次性铸造 100 万枚给部署者,不可增发
contract MyTokenV1 is ERC20 {
    /// @notice 初始供应量:100 万枚(18 位小数)
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    constructor() ERC20("MyToken", "MT") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
