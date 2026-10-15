// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {InlineMath} from "./InlineMath.sol";

/// @notice `a.add(b)` 和 `counter.increment()` 的代码都嵌在本合约里。
contract InlineCalculator {
    using InlineMath for uint256;

    uint256 public counter;

    function calculate(uint256 a, uint256 b) public pure returns (uint256) {
        return a.add(b);
    }

    function increment() public {
        counter = counter.increment();
    }
}
