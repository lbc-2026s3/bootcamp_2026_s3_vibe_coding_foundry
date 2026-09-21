// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/// @title ICrossChainReceiver — 目标链业务合约只通过 Mailbox 收消息
/// @dev 不要做成 `recipient.call(payload)`：任意 call 是教学里最容易养成的漏洞。
///      对标 Chainlink CCIP 的 `ccipReceive`：业务合约声明接口，只信任本链 Mailbox。
interface ICrossChainReceiver {
    /// @param srcDomain 源逻辑域
    /// @param sender 源链 `dispatch` 的 `msg.sender`
    /// @param payload 任意 bytes；本 demo 的 `RemoteCounter` 解码为 `uint256 delta`
    function handle(uint64 srcDomain, address sender, bytes calldata payload) external;
}
