// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice 金库底层资产。mint 无权限，只给本地测试和 anvil 演示用。
contract VaultAsset is ERC20 {
    constructor() ERC20("Vault Asset", "vASSET") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
