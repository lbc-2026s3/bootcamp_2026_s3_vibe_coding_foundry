// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice public 库函数要单独部署并 link。调用方字节码里是 PUSH20 库地址 + DELEGATECALL。
/// @dev 库不能声明状态变量。这里用固定 slot 0 演示：delegatecall 改的是调用方的 storage。
library LinkedMath {
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }

    /// @dev 只有经 DELEGATECALL 进来才会执行。直接 CALL 时 address(this) 等于库地址，编译器插入的检查会 revert。
    function writeSlot0(uint256 value) public {
        assembly {
            sstore(0, value)
        }
    }

    function readSlot0() public view returns (uint256 value) {
        assembly {
            value := sload(0)
        }
    }
}
