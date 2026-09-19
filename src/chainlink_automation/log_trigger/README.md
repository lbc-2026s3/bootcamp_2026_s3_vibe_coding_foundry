# Demo 3：日志触发 — LogTriggeredCounter

对应旧 **Chainlink Automation Log Trigger**；在 CRE 里用 **EVM Log trigger**。

## 原理

不是轮询时钟，而是：**链上先发出匹配的 event**，CRE DON 监听到后再跑 workflow。

本 demo 把「发事件」和「处理事件」放在同一合约里（学习最简单）：

1. 你（或别人）调 `bump()` → 发出 `Bumped(address indexed who)`
2. CRE Log trigger 匹配该 event
3. 链下模拟 `checkLog(log)`：校验 source / topic，把 `who` 编进 `performData`
4. onchain `performUpkeep(performData)`：`hits[who]++`，`counter++`

```text
bump() → Bumped(who)
           ↓
CRE EVM Log trigger → checkLog → AutomationReceiver → performUpkeep(who)
           ↓
hits[who]++ , counter++
```

`performUpkeep` 可被任何人调用，因此必须校验 `performData`（拒绝零地址 / 长度不对），并用 `(txHash, logIndex)` 做 demo 级去重，防止同一条 log 被重复记账。本 demo **不**证明「确实发生过该 log」（那需要更重的证明或只信任 Receiver）；上线时主要依赖 CRE DON + `AutomationReceiver` 授权。

## 合约行为

| 函数 / 状态 | 作用 |
|-------------|------|
| `bump()` | 发 `Bumped(msg.sender)` |
| `checkLog` | 校验 log，返回 `abi.encode(who)` |
| `performUpkeep` | 解析 `who`，累加 `hits` / `counter` |
| `hits(address)` | 该地址被处理次数 |
| `BUMPED_TOPIC` | `keccak256("Bumped(address)")` |

## 本地测试

```bash
forge test --match-contract LogTriggeredCounterTest -vv
```

用构造的假 `Log` 结构体测 `checkLog` → `performUpkeep`，以及错误 topic / 零地址。

## 上线测试（CRE）

### 1. 部署

记下 `LogTriggeredCounter` 地址（本 demo 里 **发 log 的合约** 和 **被 automate 的合约** 是同一个）。

### 2. migration 模板 + Receiver

```bash
cre init --template=automation-migration-ts ...
# 部署 AutomationReceiver，setCallAllowed(LogTriggeredCounter, performUpkeep selector, true)
```

### 3. 配置 Log 触发

- `migrationType`: `"LOG"`
- `targetAddress`: LogTriggeredCounter（执行 `performUpkeep`）
- `logTriggerAddress`: 同上（监听谁发的 log）
- `logTriggerEventSignature`: `"Bumped(address)"`
- `topic1` / `topic2` / `topic3`：demo 可先留空；若只想自己触发，可把 `topic1` 设成你的地址（indexed `who`）

### 4. 模拟（需要真实含该 event 的交易）

先 bump：

```bash
cast send $LOG_COUNTER "bump()" --rpc-url $RPC --private-key $PK
```

记下交易 hash，再：

```bash
cre workflow simulate my-workflow \
  --target=test-settings \
  --non-interactive \
  --trigger-index=0 \
  --evm-tx-hash=0x你的txHash \
  --evm-event-index=0
```

（参数以当前 CRE CLI 为准，见 [迁移文档](https://docs.chain.link/cre/reference/cla-migration-ts)。）

### 5. 部署与验证

```bash
cre workflow deploy my-workflow --target=production-settings

cast send $LOG_COUNTER "bump()" --rpc-url $RPC --private-key $PK
# 等 CRE 处理（通常数分钟内）
cast call $LOG_COUNTER "counter()(uint256)" --rpc-url $RPC
cast call $LOG_COUNTER "hits(address)(uint256)" $YOUR_ADDR --rpc-url $RPC
```

期望：`bump` 之后 `hits[你]` 与 `counter` 增加，并能在浏览器看到 `LogHandled`。

## 注意

- Log 触发依赖「先有事件」；只部署合约不 `bump`，workflow 不会凭空跑业务逻辑。
- 生产环境应对 `AutomationReceiver` 做 workflow 身份限制（`setExpectedAuthor` / `setExpectedWorkflowId` 等），本 demo README 从略，见官方迁移指南。
