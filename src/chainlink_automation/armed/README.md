# Demo 2：条件触发 — ArmedCounter

对应旧 **Chainlink Automation Custom Logic Upkeep**；在 CRE 里通常是 **Cron + 链下读 `checkUpkeep` + 条件成立再写 `performUpkeep`**。

## 原理

「条件触发」不是合约自己轮询，而是：

1. CRE 按 Cron 醒来（或按你设的频率）
2. **链下** `eth_call` 模拟 `checkUpkeep`（本 demo：看 `armed` 是否为 true）
3. 只有返回 `upkeepNeeded == true` 时，才生成签名报告、onchain 调 `performUpkeep`

这样 check 不耗你的 gas；真正写状态才花钱。

```text
Cron → 链下 checkUpkeep(armed?) → true?
         ├─ false → 结束（不发交易）
         └─ true  → AutomationReceiver → performUpkeep → counter++，armed=false
```

`performUpkeep` 开头再次检查 `armed`，保证幂等（防止重复执行）。

## 合约行为

| 函数 / 状态 | 作用 |
|-------------|------|
| `arm()` | 设 `armed = true`（人为制造「条件成立」） |
| `checkUpkeep` | 返回 `(armed, "")` |
| `performUpkeep` | 要求已 armed；清 armed；`counter++` |
| `armed` / `counter` | 当前是否待执行 / 已执行次数 |

## 本地测试

```bash
forge test --match-contract ArmedCounterTest -vv
```

覆盖：未 arm 不触发、arm 后可 perform、perform 后自动 disarm、重复 perform 会 revert。

## 上线测试（CRE）

### 1. 部署

记下 `ArmedCounter` 地址。

### 2. migration 模板 + Receiver

同 [总 README](../README.md)：`cre init --template=automation-migration-ts`，部署 `AutomationReceiver`。

### 3. 授权

```bash
cast sig 'performUpkeep(bytes)'
# → 0x4585e33b

# setCallAllowed(ArmedCounter, 0x4585e33b, true)
```

### 4. 配置

- `migrationType`: `"CUSTOM"`
- `targetAddress`: ArmedCounter
- `receiverAddress`: AutomationReceiver
- `schedule`: 例如每 1 分钟（便于观察；官方最短约 30s）
- check 路径按模板调用目标的 `checkUpkeep`；成立时再 encode `performUpkeep(bytes)`

### 5. 模拟

```bash
cre workflow simulate my-workflow --target=test-settings
```

建议两轮：

1. **未 arm**：应看到 check 为 false、不写链  
2. 先 `cast send $ARMED "arm()"`，再 simulate / 等 Cron：应执行一次，`armed` 变 false，`counter` +1

### 6. 部署与验证

```bash
cre workflow deploy my-workflow --target=production-settings

cast send $ARMED "arm()" --rpc-url $RPC --private-key $PK
# 等一个 schedule 周期
cast call $ARMED "armed()(bool)" --rpc-url $RPC
cast call $ARMED "counter()(uint256)" --rpc-url $RPC
```

期望：arm 之后不久 `armed() == false` 且 `counter` 增加。

## 和「定时触发」的差别

定时案例**不管**链上状态，到点就调；本案例到点只是「来看一眼」，**状态不满足就不写链**——这才是 Custom Logic / Keeper 的核心。
