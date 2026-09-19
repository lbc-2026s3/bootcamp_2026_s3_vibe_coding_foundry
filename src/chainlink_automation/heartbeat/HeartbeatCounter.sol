// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/// @title HeartbeatCounter — 定时触发 demo（CLA Time-based / CRE Cron）
/// @notice 普通合约，不实现 Automation 接口。CRE Cron（或旧 Time-based Upkeep）到点直接调 `pulse()`。
contract HeartbeatCounter {
    uint256 public counter;
    uint256 public lastPulseAt;

    event Pulsed(uint256 indexed newCounter, uint256 pulsedAt);

    /// @notice 由 CRE Cron workflow / AutomationReceiver 转发调用；任何人也可手动调用做本地验证。
    function pulse() external {
        unchecked {
            ++counter;
        }
        lastPulseAt = block.timestamp;
        emit Pulsed(counter, lastPulseAt);
    }
}
