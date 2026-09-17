// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Counter} from "./Counter.sol";

/// @notice V2：在 V1 上追加 `decrement`（无新存储字段，无需 reinitializer）。
/// @custom:oz-upgrades-from Counter
contract CounterV2 is Counter {
    function decrement() public {
        number--;
    }
}
