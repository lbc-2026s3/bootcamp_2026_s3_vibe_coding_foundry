// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/// @title LuckyDraw — Chainlink VRF v2.5 Subscription demo
/// @notice 玩家 `enterDraw()` 请求 1 个随机词；Coordinator 验 proof 后回调，写入 `1..100` 中奖号。
/// @dev 「可验证」由 VRF Coordinator 完成（链下 DON 生成随机数 + proof，链上 Coordinator 验 proof）。
///      本合约不自己验 proof：只接受 Coordinator 的 `rawFulfillRandomWords`，并用 `requestId → player` 绑定归属。
///      继承 `VRFConsumerBaseV2Plus` 后，部署者是 Owner，可调用基类 `setCoordinator` 迁移 Coordinator。
contract LuckyDraw is VRFConsumerBaseV2Plus {
    /// @notice Coordinator 等待的区块确认数（Sepolia 最小一般为 3）。
    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    /// @notice 每次请求返回几个随机词；本 demo 只要 1 个。
    uint32 public constant NUM_WORDS = 1;

    /// @notice VRF Subscription ID（在 vrf.chain.link 创建并充 LINK）。
    uint256 public immutable i_subscriptionId;
    /// @notice gas lane keyHash：标识链下 VRF job，也限制愿意付的最高 gas price。
    bytes32 public immutable i_keyHash;
    /// @notice 回调 `fulfillRandomWords` 可用的 gas 上限；不够会扣费但回填失败。
    uint32 public immutable i_callbackGasLimit;

    /// @notice requestId → 发起请求的玩家（fulfill 后删除）。
    mapping(uint256 requestId => address player) public s_requestToPlayer;
    /// @notice 玩家当前未完成的 requestId；0 表示无 pending。
    mapping(address player => uint256 requestId) public s_pendingRequest;
    /// @notice 玩家中奖号：0 = 未开奖，1..100 = 已出结果。
    mapping(address player => uint256 ticket) public s_tickets;

    /// @notice 已向 Coordinator 发出随机数请求。
    event DrawRequested(uint256 indexed requestId, address indexed player);
    /// @notice Coordinator 回填完成，中奖号已写入。
    event TicketDrawn(uint256 indexed requestId, address indexed player, uint256 ticket);

    error AlreadyDrawn();
    error DrawPending();
    error NoTicket();
    error StillPending();
    error UnknownRequest();

    /// @param coordinator VRF Coordinator 地址（Sepolia: `0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B`）
    /// @param subscriptionId 已 funded 的 subscription id
    /// @param keyHash 该网 gas lane（Sepolia 500 gwei lane 见 README）
    /// @param callbackGasLimit 回调 gas 上限（本 demo 默认 100_000）
    constructor(address coordinator, uint256 subscriptionId, bytes32 keyHash, uint32 callbackGasLimit)
        VRFConsumerBaseV2Plus(coordinator)
    {
        i_subscriptionId = subscriptionId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
    }

    /// @notice 任意地址可参与一次抽奖；已有 pending / 已出结果则 revert。
    /// @dev 每次请求从 subscription 扣 LINK；公开 demo 勿充太多余额。
    ///      `nativePayment: false` = 用 LINK 付费；改 `true` 则用原生币余额。
    /// @return requestId Coordinator 返回的请求 id，用于追踪回调。
    function enterDraw() external returns (uint256 requestId) {
        // 每人只能成功开奖一次；已出票不可再抽
        if (s_tickets[msg.sender] != 0) revert AlreadyDrawn();
        // 上一笔还在等 DON 回填时不可重复请求（否则会重复扣费）
        if (s_pendingRequest[msg.sender] != 0) revert DrawPending();

        // 向 Coordinator 发起 Request-and-Receive；未 addConsumer / 余额不足会在此 revert
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        // 绑定 requestId ↔ player，回调时靠这个还原归属
        s_requestToPlayer[requestId] = msg.sender;
        s_pendingRequest[msg.sender] = requestId;
        emit DrawRequested(requestId, msg.sender);
    }

    /// @notice Coordinator 验完 proof 后回调；把随机词映射为 `1..100` 写入状态。
    /// @dev 外部入口是基类 `rawFulfillRandomWords`（仅 Coordinator 可调），再转到本函数。
    ///      不要把此函数改成 public/external，否则任何人可伪造随机数。
    /// @param requestId 当初 `enterDraw` 拿到的 id
    /// @param randomWords 长度应为 `NUM_WORDS`；本 demo 只用 `[0]`
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        address player = s_requestToPlayer[requestId];
        // 未知 requestId 不写状态，避免误写 address(0)
        if (player == address(0)) revert UnknownRequest();

        // 映射到闭区间 [1, 100]；结果永不为 0，不会与「未开奖」冲突
        uint256 ticket = (randomWords[0] % 100) + 1;

        s_tickets[player] = ticket;
        delete s_pendingRequest[player];
        delete s_requestToPlayer[requestId];
        emit TicketDrawn(requestId, player, ticket);
    }

    /// @notice 读取玩家中奖号；未开奖 / 进行中会 revert，便于前端区分状态。
    /// @return ticket `1..100`
    function getTicket(address player) external view returns (uint256 ticket) {
        ticket = s_tickets[player];
        if (ticket == 0) {
            if (s_pendingRequest[player] != 0) revert StillPending();
            revert NoTicket();
        }
    }

    /// @notice 玩家当前 pending 的 requestId；`0` 表示没有进行中的请求。
    function getPendingRequest(address player) external view returns (uint256 requestId) {
        return s_pendingRequest[player];
    }
}
