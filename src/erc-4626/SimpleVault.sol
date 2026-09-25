// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice 份额化储蓄金库。收益就是多转入、但不增发份额的底层资产。
/// @dev deposit / mint / withdraw / redeem 与汇率全部用 OpenZeppelin ERC4626，不改虚拟份额。
contract SimpleVault is ERC4626 {
    using SafeERC20 for IERC20;

    event Donated(address indexed donor, uint256 assets);

    error ZeroAssets();

    constructor(IERC20 asset_) ERC20("Simple Vault Share", "svASSET") ERC4626(asset_) {}

    /// @notice 向金库转入额外资产且不铸造份额，于是每个已有份额可赎回的资产变多。
    // donate:捐赠
    function donate(uint256 assets) external {
        if (assets == 0) revert ZeroAssets();
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
        emit Donated(msg.sender, assets);
    }
}
