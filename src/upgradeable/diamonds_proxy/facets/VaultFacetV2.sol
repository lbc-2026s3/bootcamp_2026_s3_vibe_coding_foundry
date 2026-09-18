// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IVaultV2} from "../interfaces/IVaultV2.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {VaultBase} from "../libraries/VaultBase.sol";

/// @notice 只替换 `withdraw` 并 Add 费率只读函数；`deposit` 仍走 PointsFacet（若已升级）或 V1 VaultFacet。
contract VaultFacetV2 is IVaultV2, VaultBase {
    function withdraw(uint256 amount) external nonReentrant {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        _withdraw(msg.sender, amount, s.withdrawFeeBps);
    }

    function withdrawFeeBps() external view returns (uint256) {
        return LibAppStorage.appStorage().withdrawFeeBps;
    }

    function protocolFees() external view returns (uint256) {
        return LibAppStorage.appStorage().protocolFees;
    }
}
