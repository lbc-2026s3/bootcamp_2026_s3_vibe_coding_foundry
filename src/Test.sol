// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice 存储布局演示。构造函数写入固定初值，供链下按槽位读取。
/// 槽位 0: [c (uint128, 高 16 字节)][a (uint128, 低 16 字节)]
/// 槽位 1: [12 字节空白][b (address, 低 20 字节)]
/// 槽位 2: balances 的 mapping 基槽（本身为 0）
///         balances[key] 位于 keccak256(abi.encode(key, 2))
contract Test {
    struct Optimized {
        uint128 a;
        uint128 c;
        address b;
    }

    Optimized public a;
    mapping(address => uint256) public balances;

    /// @dev Anvil 默认账户 #1。后端读槽脚本的默认 key 与此相同。
    address public constant DEMO_ACCOUNT = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint128 public constant INITIAL_A = 42;
    uint128 public constant INITIAL_C = 7;
    uint256 public constant INITIAL_BALANCE = 1000;

    constructor() {
        a = Optimized({a: INITIAL_A, c: INITIAL_C, b: DEMO_ACCOUNT});
        balances[DEMO_ACCOUNT] = INITIAL_BALANCE;
    }
}
