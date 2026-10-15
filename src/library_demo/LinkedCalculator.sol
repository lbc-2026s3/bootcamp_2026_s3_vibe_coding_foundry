// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LinkedMath} from "./LinkedMath.sol";

/// @notice 源码里同样是 `a.add(b)`，但 add 是 public，所以这是一次对已 link 库的 DELEGATECALL。
contract LinkedCalculator {
    using LinkedMath for uint256;

    /// @dev 与 LinkedMath.writeSlot0 / readSlot0 使用的 slot 0 对齐。
    uint256 public counter;

    function calculate(uint256 a, uint256 b) public pure returns (uint256) {
        return a.add(b);
    }

    function increment() public {
        LinkedMath.writeSlot0(counter + 1);
    }
}
