// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice internal 库函数会在编译期拷进调用合约，运行时是 JUMP，不会单独部署。
library InlineMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function increment(uint256 current) internal pure returns (uint256) {
        return current + 1;
    }
}
