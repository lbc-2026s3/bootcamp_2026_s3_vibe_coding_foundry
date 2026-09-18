// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IPoints} from "../interfaces/IPoints.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {VaultBase} from "../libraries/VaultBase.sol";

/// @notice Add 本 facet：`pointsOf`；Replace `deposit` 后，新存款按 1:1（wei）记积分。
contract PointsFacet is IPoints, VaultBase {
    function deposit() external payable nonReentrant {
        _deposit(msg.sender, msg.value);
        _accruePoints(msg.sender, msg.value);
    }

    function pointsOf(address user) external view returns (uint256) {
        return LibAppStorage.appStorage().points[user];
    }
}
