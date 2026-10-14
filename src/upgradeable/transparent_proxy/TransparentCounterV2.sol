// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {TransparentCounter} from "./TransparentCounter.sol";

/// @notice V2：仍不包含升级逻辑，只在 V1 存储末尾追加 `decrements`。
/// @dev 升级由 ProxyAdmin.upgradeAndCall 完成。新变量默认 0，无需 reinitializer。
/// @custom:oz-upgrades-from TransparentCounter
contract TransparentCounterV2 is TransparentCounter {
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
