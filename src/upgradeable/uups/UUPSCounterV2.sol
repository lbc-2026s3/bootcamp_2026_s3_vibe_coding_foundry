// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {UUPSCounter} from "./UUPSCounter.sol";

/// @notice V2：保留 UUPS 升级能力，并在 V1 存储末尾追加 `decrements`。
/// @dev 新变量默认 0，无需 reinitializer。不得在 V1 变量之前插入或重排字段。
/// @custom:oz-upgrades-from UUPSCounter
contract UUPSCounterV2 is UUPSCounter {
    /// @notice `decrement` 成功调用的次数。
    uint256 public decrements;

    function decrement() public {
        number--;
        decrements++;
    }

    function version() public pure override returns (uint256) {
        return 2;
    }
}
