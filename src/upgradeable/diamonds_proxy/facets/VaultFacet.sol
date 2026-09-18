// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IVault} from "../interfaces/IVault.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {VaultBase} from "../libraries/VaultBase.sol";

/// @notice V1 金库：存 / 取 ETH，不计积分、无手续费。
contract VaultFacet is IVault, VaultBase {
    function deposit() external payable nonReentrant {
        _deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        _withdraw(msg.sender, amount, 0);
    }

    function balanceOf(address user) external view returns (uint256) {
        return LibAppStorage.appStorage().balances[user];
    }

    function totalDeposits() external view returns (uint256) {
        return LibAppStorage.appStorage().totalDeposits;
    }
}
