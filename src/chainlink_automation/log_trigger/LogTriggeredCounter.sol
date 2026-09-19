// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ILogAutomation, Log} from "../interfaces/ILogAutomation.sol";

/// @title LogTriggeredCounter — 日志触发 demo（CLA Log Trigger / CRE EVM Log trigger）
/// @notice 链路：`bump()` 发 `Bumped` → CRE/Automation 监听到日志 → 链下 `checkLog` → 链上 `performUpkeep` 记账。
/// @dev 本合约既是「发 log 的源」，也是「被 automate 的目标」；生产里也可以拆成两个合约。
contract LogTriggeredCounter is ILogAutomation {
    /// @notice `Bumped(address)` 的 event topic0（非 indexed 参数不进 topics，只进 data）。
    bytes32 public constant BUMPED_TOPIC = keccak256("Bumped(address)");

    /// @notice 全局已成功 perform 的次数。
    uint256 public counter;
    /// @notice 每个 `who` 被处理的次数。
    mapping(address => uint256) public hits;
    /// @notice 按 logId 去重：同一条 log 只允许 perform 一次。
    /// @dev logId = keccak256(abi.encode(txHash, logIndex))；键是稀疏哈希，用 mapping(bool) 即可。
    mapping(bytes32 => bool) public processedLog;

    event Bumped(address indexed who);
    event LogHandled(address indexed who, uint256 indexed newHits, bytes32 indexed logId);

    error AlreadyProcessed();
    error BadPerformData();

    /// @notice 人为制造一条触发日志（本地 / 测试网验证用）。
    function bump() external {
        emit Bumped(msg.sender);
    }

    /// @notice 链下模拟：判断这条 log 要不要触发 onchain perform。
    /// @dev 不匹配时返回 `(false, "")`，不要 revert——否则 CRE/Automation 会当成 check 失败，而不是「跳过」。
    /// @param log CRE/Automation 把匹配到的原始 log 填成的结构体。
    /// @return upkeepNeeded 是否需要执行 `performUpkeep`。
    /// @return performData 传给 `performUpkeep` 的编码数据（本 demo：who + txHash + logIndex）。
    function checkLog(Log calldata log, bytes memory /* checkData */)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // 只处理本合约自己发出的 Bumped
        if (log.source != address(this)) return (false, "");
        // topics[0]=event sig，topics[1]=indexed who；至少要有这两项
        if (log.topics.length < 2) return (false, "");
        if (log.topics[0] != BUMPED_TOPIC) return (false, "");

        // indexed address 存在 topics[1] 的低 160 bit
        address who = address(uint160(uint256(log.topics[1])));
        if (who == address(0)) return (false, "");

        // 已处理过则不再需要 upkeep
        bytes32 logId = keccak256(abi.encode(log.txHash, log.index));
        if (processedLog[logId]) return (false, "");

        upkeepNeeded = true;
        // 链上 perform 需要能还原 who，并用 (txHash, index) 做去重
        performData = abi.encode(who, log.txHash, log.index);
    }

    /// @notice 链上执行：校验 performData、去重、记账。
    /// @dev 任何人都能调此函数，所以必须自校验；不可盲信 checkLog 的返回值。
    /// @param performData 期望为 abi.encode(address who, bytes32 txHash, uint256 logIndex)，共 96 字节。
    function performUpkeep(bytes calldata performData) external override {
        // address(32) + bytes32(32) + uint256(32) = 96
        if (performData.length != 96) revert BadPerformData();
        (address who, bytes32 txHash, uint256 logIndex) = abi.decode(performData, (address, bytes32, uint256));
        if (who == address(0)) revert BadPerformData();

        bytes32 logId = keccak256(abi.encode(txHash, logIndex));
        if (processedLog[logId]) revert AlreadyProcessed();
        processedLog[logId] = true;

        unchecked {
            ++hits[who];
            ++counter;
        }
        emit LogHandled(who, hits[who], logId);
    }
}
