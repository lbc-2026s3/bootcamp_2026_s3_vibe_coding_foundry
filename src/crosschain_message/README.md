# Trusted Relayer Message Passing Demo

用两份合约演示 **任意消息跨链：源链只发事件，目标链由 relayer 回调业务合约**。和 lock-and-mint demo **零代码依赖**；重复的 nonce / `onlyRelayer` / 重放保护是故意的，方便对照「资产跨链只是一种特定 payload」。

两条「链」在本地是同一条 EVM，靠逻辑 domain（`1` / `2`）区分，不用 `block.chainid`。

**信任模型：本 demo 等于中心化预言机。** Relayer 可伪造 payload 去调已部署的 `handle`。生产协议（CCIP 等）把搬运 + 验证产品化；本仓库不接 CCIP。

## 心智模型（远程调用也要搬运工）

`dispatch` 不会在对端执行任何函数。必须有人 `deliver`。`RemoteCounter.handle` **只接受本链 Mailbox**（对标 VRF 只接受 Coordinator）。禁止 `recipient.call(payload)`。

```text
User                 Mailbox (domain 1)          Relayer          Mailbox (domain 2)     RemoteCounter
 │                         │                       │                    │                     │
 │── dispatch(payload) ───►│                       │                    │                     │
 │                         │── MessageDispatched ─►│                    │                     │
 │                         │                       │── deliver(...) ──►│                     │
 │                         │                       │                    │── handle(...) ────►│
 │                         │                       │                    │                     │── count += delta
```

| 谁调用 | 做什么 | 没人调用会怎样 |
|--------|--------|----------------|
| 用户 `dispatch` | 源 Mailbox 记 nonce、发事件 | 无跨链意图 |
| 仅 relayer `deliver` | 防重放后调 `recipient.handle` | `RemoteCounter.s_count` 一直为 0 |
| 仅本链 Mailbox `handle` | 解码 `uint256 delta` 并累加 | 直调会 `NotMailbox` |
| owner `setRelayer` | 换搬运工 | 旧 relayer 不能 `deliver` |

`messageId = keccak256(abi.encode(srcDomain, destDomain, nonce, sender, recipient, keccak256(payload)))`。

payload 本 demo 为 `abi.encode(uint256 delta)`。空 payload revert。

## 合约

- [`ICrossChainReceiver.sol`](./ICrossChainReceiver.sol)：目标链回调接口。
- [`MessageMailbox.sol`](./MessageMailbox.sol)：两边各部署一份；`dispatch` / `deliver`。
- [`RemoteCounter.sol`](./RemoteCounter.sol)：只信任构造时注入的 Mailbox。

## 本地测试

```bash
cd bootcamp_2026_s3_vibe_coding_foundry
forge test --match-path 'test/crosschain_message/*' -vv
```

覆盖：成功累加、relayer 停机、非 relayer、重放、直调 `handle`、错误 destDomain、空 payload。

## 本地 Anvil 走通（可选，不强制）

```bash
anvil

forge script script/crosschain_message/DeployMessage.s.sol --broadcast \
  --rpc-url local --private-key $LOCAL_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

```bash
export SRC=<SourceMailbox>
export DST=<DestMailbox>
export COUNTER=<RemoteCounter>
export USER=<your address>

# payload = abi.encode(uint256(7))
cast send $SRC "dispatch(uint64,address,bytes)" 2 $COUNTER \
  0x0000000000000000000000000000000000000000000000000000000000000007 \
  --rpc-url local --private-key $LOCAL_PRIVATE_KEY

# nonce 从 1 起
cast send $DST "deliver(uint64,uint64,uint64,address,address,bytes)" \
  1 2 1 $USER $COUNTER \
  0x0000000000000000000000000000000000000000000000000000000000000007 \
  --rpc-url local --private-key $LOCAL_PRIVATE_KEY

cast call $COUNTER "s_count()(uint256)" --rpc-url local
```

可选覆盖：`MESSAGE_RELAYER` / `MESSAGE_HOME` / `MESSAGE_REMOTE`。

## 刻意不做

- 不接 CCIP / LayerZero
- 不做任意 `call(payload)`
- 不做前端、gas 支付、多 receiver 注册表
- 不 import lock-and-mint demo
- 不把 `block.chainid` 当 domain
