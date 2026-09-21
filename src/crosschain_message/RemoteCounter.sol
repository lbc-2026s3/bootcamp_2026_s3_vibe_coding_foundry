// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ICrossChainReceiver} from "./ICrossChainReceiver.sol";

/// @title RemoteCounter — 目标链业务合约：跨链把 `count` 加上 payload 里的 delta
/// @notice `handle` 只接受本链 Mailbox（对标 VRF 只接受 Coordinator）。
/// @dev payload = abi.encode(uint256 delta)。任何人直调 `handle` 都会 revert。
contract RemoteCounter is ICrossChainReceiver {
    /// @notice 本链唯一可信的消息入口。
    address public immutable i_mailbox;
    /// @notice 被跨链消息累加的计数。
    uint256 public s_count;
    /// @notice 最近一次成功 handle 的源域 / 发送者，便于对照测试。
    uint64 public s_lastSrcDomain;
    address public s_lastSender;

    event Counted(uint64 indexed srcDomain, address indexed sender, uint256 delta, uint256 newCount);

    error NotMailbox();

    constructor(address mailbox) {
        if (mailbox == address(0)) revert NotMailbox();
        i_mailbox = mailbox;
    }

    /// @inheritdoc ICrossChainReceiver
    function handle(uint64 srcDomain, address sender, bytes calldata payload) external {
        if (msg.sender != i_mailbox) revert NotMailbox();

        uint256 delta = abi.decode(payload, (uint256));
        s_count += delta;
        s_lastSrcDomain = srcDomain;
        s_lastSender = sender;
        emit Counted(srcDomain, sender, delta, s_count);
    }
}
