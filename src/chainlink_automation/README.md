# Chainlink Automation → CRE 三种触发 Demo

[automation.chain.link](https://automation.chain.link/) 已在弃用：页面明确写着 **Chainlink Automation is being deprecated**，继任者是 **[Chainlink Runtime Environment (CRE)](https://docs.chain.link/cre)**。

本目录用三个极简合约演示原来 CLA 的三种触发玩法，并按 **CRE** 说明如何上线测试。合约仍保留 CLA 兼容接口（`checkUpkeep` / `checkLog` / `performUpkeep`），这样可直接套用官方 [Automation → CRE 迁移模板](https://docs.chain.link/cre/reference/cla-migration-ts)。

## 日落时间（官方）

| 产品 | 日落 |
|------|------|
| Automation v1.x | 2026-06-30 |
| Automation v2.1（测试网） | 2026-06-24 |
| Automation v2.1（主网） | 2026-07-31 |

新项目请走 CRE，不要再往 Automation App 注册新 Upkeep。

## 心智模型

智能合约**不会自己执行**。CRE workflow（WASM，跑在 DON 上）负责：

1. **触发**：Cron / EVM Log /（HTTP 等）
2. **链下逻辑**：读状态、判断是否该做事（取代 `checkUpkeep`）
3. **链上写入**：经 `KeystoneForwarder` → 你的 `IReceiver` / `AutomationReceiver` → 调目标合约

```text
CLA 概念              CRE 对应
─────────────         ──────────────────────────
Time-based Upkeep  →  Cron trigger
Custom Logic       →  Cron + 链下 callContract(check) + 有条件 write
Log Trigger        →  EVM Log trigger
performUpkeep      →  onReport → bridge call 目标函数
Automation App     →  https://app.chain.link/cre （CLI + UI）
```

## 三个案例

| 目录 | 合约 | 旧 CLA 触发 | CRE 触发 |
|------|------|-------------|----------|
| [`heartbeat/`](./heartbeat/) | `HeartbeatCounter` | Time-based | Cron → 调 `pulse()` |
| [`armed/`](./armed/) | `ArmedCounter` | Custom logic | Cron → 读 `checkUpkeep` → 条件成立再 `performUpkeep` |
| [`log_trigger/`](./log_trigger/) | `LogTriggeredCounter` | Log trigger | EVM Log(`Bumped`) → `checkLog` → `performUpkeep` |

每个子目录有独立 `README.md`：原理 + 本地测 + CRE 上线步骤。

## 本地测试（本仓库）

```bash
cd bootcamp_2026_s3_vibe_coding_foundry
forge test --match-path 'test/chainlink_automation/*' -vv
```

## 部署目标合约（例如 Sepolia）

```bash
forge script script/chainlink_automation/DeployAutomationDemos.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

记下三个地址，后面填进 CRE workflow 的 `config.*.json`。

## CRE 上线总览（三个案例共用）

1. 注册 CRE 账号：[app.chain.link/cre/discover](https://app.chain.link/cre/discover)
2. 安装 CLI：`curl -sSL https://app.chain.link/cre/install.sh | bash`
3. 用官方迁移模板脚手架（最贴合本 demo 的三种类型）：

```bash
cre init --template=automation-migration-ts \
  --project-name automation-demos \
  --workflow-name my-workflow
```

4. 部署模板里的 `AutomationReceiver`（构造函数传入该链的 [KeystoneForwarder](https://docs.chain.link/cre) 地址）
5. 对每个目标合约 `setCallAllowed(target, selector, true)`：
   - Heartbeat：`cast sig 'pulse()'`
   - Armed / Log：`cast sig 'performUpkeep(bytes)'` → `0x4585e33b`
6. 在 `config.*.json` 设 `migrationType` 为 `CRON` / `CUSTOM` / `LOG`（见各案例 README）
7. 模拟：`cre workflow simulate my-workflow --target=test-settings`
8. 部署到 DON 需申请权限：`cre account access`，通过后再 `cre workflow deploy ...`

更完整的概念对照见：[Migrate CLA → CRE](https://docs.chain.link/cre/reference/cla-migration-ts)。纯 Cron 维护也可看 [Keeper Bot 模板](https://docs.chain.link/cre-templates/keeper-bot)。

## 刻意不做

- 不在本 Foundry 仓库内嵌完整 TypeScript CRE workflow（用官方 `cre init` 模板更干净）
- 不接 Data Streams / Functions
- 不演示已弃用的 automation.chain.link 注册流程
