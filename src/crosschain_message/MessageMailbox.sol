// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ICrossChainReceiver} from "./ICrossChainReceiver.sol";

/// @title MessageMailbox — trusted relayer 通用消息通道
/// @notice 源链 `dispatch` 只写事件；relayer 在目标链 `deliver`，再回调 `ICrossChainReceiver.handle`。
/// @dev 本合约不能自己去对端执行。没人当 relayer，`RemoteCounter` 永远是 0。
///      信任模型：relayer 等价于中心化预言机，可伪造任意 payload 调用已部署的 receiver。
///      故意不 import lock-and-mint demo：对照「资产 vs 消息」时，重复的 nonce / 重放保护就是重点。
contract MessageMailbox is Ownable, ReentrancyGuard {
    /// @notice 本端逻辑域。单链测试用构造函数注入，不要用 `block.chainid`。
    uint64 public immutable i_localDomain;
    /// @notice 对端逻辑域。
    uint64 public immutable i_peerDomain;

    /// @notice 唯一被授权 `deliver` 的搬运工。
    address public s_relayer;
    /// @notice 下一笔 `dispatch` 使用的 nonce（从 1 起）。
    uint64 public s_nonce;
    /// @notice 已投递消息，防重放。
    mapping(bytes32 messageId => bool processed) public s_processed;

    event MessageDispatched(
        bytes32 indexed messageId,
        uint64 indexed srcDomain,
        uint64 destDomain,
        uint64 nonce,
        address sender,
        address recipient,
        bytes payload
    );
    event MessageDelivered(
        bytes32 indexed messageId,
        uint64 indexed srcDomain,
        uint64 destDomain,
        uint64 nonce,
        address sender,
        address recipient,
        bytes payload
    );
    event RelayerUpdated(address indexed previousRelayer, address indexed newRelayer);

    error ZeroAddress();
    error ZeroRelayer();
    error InvalidDomain();
    error SameDomain();
    error NotRelayer();
    error UnknownSourceDomain(uint64 srcDomain);
    error InvalidDestDomain(uint64 destDomain);
    error AlreadyProcessed(bytes32 messageId);
    error EmptyPayload();
    error RecipientNotContract(address recipient);

    modifier onlyRelayer() {
        if (msg.sender != s_relayer) revert NotRelayer();
        _;
    }

    constructor(uint64 localDomain, uint64 peerDomain, address relayer, address owner) Ownable(owner) {
        if (localDomain == 0 || peerDomain == 0) revert InvalidDomain();
        if (localDomain == peerDomain) revert SameDomain();
        if (relayer == address(0)) revert ZeroRelayer();

        i_localDomain = localDomain;
        i_peerDomain = peerDomain;
        s_relayer = relayer;
        emit RelayerUpdated(address(0), relayer);
    }

    /// @notice 发出跨链消息。`destDomain` 必须是 peer；`recipient` 是对端 receiver。
    /// @dev 无人 `deliver` 时目标合约状态不变。
    function dispatch(uint64 destDomain, address recipient, bytes calldata payload)
        external
        returns (bytes32 messageId)
    {
        if (destDomain != i_peerDomain) revert InvalidDestDomain(destDomain);
        if (recipient == address(0)) revert ZeroAddress();
        if (payload.length == 0) revert EmptyPayload();

        uint64 nonce = ++s_nonce;
        messageId = computeMessageId(i_localDomain, destDomain, nonce, msg.sender, recipient, payload);
        emit MessageDispatched(messageId, i_localDomain, destDomain, nonce, msg.sender, recipient, payload);
    }

    /// @notice relayer 把源链消息投递到本域 `recipient.handle`。
    /// @dev 先标记 processed 再外部调用（CEI）。不使用任意 `call`。
    function deliver(
        uint64 srcDomain,
        uint64 destDomain,
        uint64 nonce,
        address sender,
        address recipient,
        bytes calldata payload
    ) external nonReentrant onlyRelayer {
        if (srcDomain != i_peerDomain) revert UnknownSourceDomain(srcDomain);
        if (destDomain != i_localDomain) revert InvalidDestDomain(destDomain);
        if (sender == address(0) || recipient == address(0)) revert ZeroAddress();
        if (payload.length == 0) revert EmptyPayload();
        if (recipient.code.length == 0) revert RecipientNotContract(recipient);

        bytes32 messageId = computeMessageId(srcDomain, destDomain, nonce, sender, recipient, payload);
        if (s_processed[messageId]) revert AlreadyProcessed(messageId);

        s_processed[messageId] = true;
        emit MessageDelivered(messageId, srcDomain, destDomain, nonce, sender, recipient, payload);
        ICrossChainReceiver(recipient).handle(srcDomain, sender, payload);
    }

    function setRelayer(address newRelayer) external onlyOwner {
        if (newRelayer == address(0)) revert ZeroRelayer();
        address previous = s_relayer;
        s_relayer = newRelayer;
        emit RelayerUpdated(previous, newRelayer);
    }

    function computeMessageId(
        uint64 srcDomain,
        uint64 destDomain,
        uint64 nonce,
        address sender,
        address recipient,
        bytes memory payload
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(srcDomain, destDomain, nonce, sender, recipient, keccak256(payload)));
    }
}
