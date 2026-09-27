// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice 演示用 ERC20。mint 无权限，只给本地测试和 anvil。
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /// @notice 给 to 铸造 amount 个代币。
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
