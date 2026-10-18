// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice 一个槽里放三个变量。说明见 docs/evm-storage-endian.md。
/// 槽位 0，Solidity 从低位开始打包：
///   x uint64  offset 0  位 [63:0]    十六进制右端 8 字节
///   y uint64  offset 8  位 [127:64]  中间 8 字节
///   z uint128 offset 16 位 [255:128] 十六进制左端 16 字节
contract PackedSlot {
    uint64 public x;
    uint64 public y;
    uint128 public z;

    constructor(uint64 x_, uint64 y_, uint128 z_) {
        x = x_;
        y = y_;
        z = z_;
    }

    function raw() external view returns (bytes32 word) {
        assembly {
            word := sload(0)
        }
    }

    /// @dev 右移位数 = 编译器 storage layout 里的 byte offset × 8。
    ///      再收到目标类型的宽度，高位被截掉。
    function unpack() external view returns (uint64 x_, uint64 y_, uint128 z_) {
        uint256 word;
        assembly {
            word := sload(0)
        }
        x_ = uint64(word);
        y_ = uint64(word >> 64);
        z_ = uint128(word >> 128);
    }
}
