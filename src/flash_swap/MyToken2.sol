// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice 演示 ERC20：部署时铸造 1_000_000 枚给部署者，不可增发
contract MyToken2 is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    constructor() ERC20("MyToken2", "MT2") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
