# Demo 1：定时触发 — HeartbeatCounter

对应旧 **Chainlink Automation Time-based Upkeep**；在 CRE 里用 **Cron trigger**。

## 原理

合约没有「闹钟」。`pulse()` 只是一个普通函数：谁调、谁付 gas，计数就 +1。

CRE 的 Cron workflow 按 CRON 表达式周期性醒来，经 `AutomationReceiver`（或其它 `IReceiver`）转发调用 `pulse()`，于是你看到 `counter` 随时间增长。

```text
Cron 到点 → CRE workflow → KeystoneForwarder → AutomationReceiver → pulse()
```

本合约**不实现** `checkUpkeep`：触发条件完全在链下调度器，不看链上状态。

注意：`pulse()` 是 permissionless 的，任何人都能调——本地调试方便，但公开测试网上别人也能抬高 `counter`，所以它不能单独当作「CRE 是否在跑」的铁证；结合 `Pulsed` 事件时间戳 / CRE 执行日志一起看更稳妥。

## 合约行为

| 函数 / 状态 | 作用 |
|-------------|------|
| `pulse()` | `counter++`，写 `lastPulseAt`，发 `Pulsed` |
| `counter` | 心跳次数 |
| `lastPulseAt` | 上次心跳时间戳 |

## 本地测试

```bash
forge test --match-contract HeartbeatCounterTest -vv
```

本地只能验证「调用 `pulse` 会改状态」；**真实周期**必须靠 CRE Cron（或你自己写脚本）触发。

## 上线测试（CRE）

### 1. 部署

用仓库脚本部署后，从 `deployments/LATEST.txt` 取 `HeartbeatCounter` 地址。

### 2. 脚手架 migration 模板

```bash
cre init --template=automation-migration-ts \
  --project-name heartbeat-cre \
  --workflow-name heartbeat
```

部署模板中的 `AutomationReceiver`，构造参数为该链 CRE `KeystoneForwarder`（见 [Forwarder Directory / CRE 文档](https://docs.chain.link/cre)）。

### 3. 授权调用

```bash
# selector
cast sig 'pulse()'

# 在 AutomationReceiver 上：
# setCallAllowed(HeartbeatCounter地址, pulse()的selector, true)
```

### 4. 配置 workflow

在 `config.test.json`（名称以模板为准）中：

- `migrationType`: `"CRON"`
- `targetAddress`: HeartbeatCounter
- `receiverAddress`: AutomationReceiver
- `schedule`: 例如 `"*/5 * * * *"`（每 5 分钟；CRE 最短间隔约 30s）
- `targetFunction`: `"pulse()"`
- `targetInputs`: 按模板填空数组 / 空串

### 5. 模拟与部署

```bash
cre workflow simulate heartbeat --target=test-settings
# 确认无误且已有 deploy 权限后：
cre workflow deploy heartbeat --target=production-settings
```

### 6. 如何确认成功

等 1～2 个 CRON 周期后：

```bash
cast call $HEARTBEAT "counter()(uint256)" --rpc-url $RPC
cast call $HEARTBEAT "lastPulseAt()(uint256)" --rpc-url $RPC
```

或在浏览器上看 `Pulsed` 事件。`counter` 增加即说明定时链路通了。

## 和「条件触发」的差别

| | 本案例（定时） | ArmedCounter（条件） |
|--|----------------|----------------------|
| 触发依据 | 墙上时钟（Cron） | 链上状态 `armed` |
| 合约接口 | 普通函数即可 | 需要 `checkUpkeep` / `performUpkeep` |
| 没人 arm 时 | 仍会按点调用 | check 为 false，不写链 |
