# Chainlink VRF v2.5 LuckyDraw Demo

用一个极简合约演示 [Chainlink VRF v2.5 Subscription](https://docs.chain.link/vrf/v2-5/getting-started)：**请求随机数 → Coordinator 验 proof 回填 → 链上读中奖号**。

## 心智模型（「可验证」验证了什么）

链上密码学证明由 **VRF Coordinator** 校验，再回调 consumer。业务合约不自己验 proof，而是：

1. 只接受 Coordinator 的 `rawFulfillRandomWords`（基类强制）
2. 用 `requestId → player` 绑定结果归属
3. 事件 + 公开 getter 让任何人核对链上结果

```text
User                LuckyDraw              VRFCoordinator           Chainlink DON
 │                     │                         │                        │
 │── enterDraw() ─────►│                         │                        │
 │                     │── requestRandomWords ──►│                        │
 │                     │◄──── requestId ─────────│                        │
 │                     │                         │◄── fulfill(proof) ─────│
 │                     │◄── fulfillRandomWords ──│  (验 proof 成功才回调)  │
 │◄─ TicketDrawn(1..100)                         │                        │
```

| 谁调用 | 做什么 |
|--------|--------|
| 玩家 `enterDraw()` | 发起请求；无人调则无请求 |
| 仅 Coordinator `fulfillRandomWords` | 回填随机数；订阅未 funded / consumer 未加白名单时会一直 pending |
| 任何人 `getTicket` / `getPendingRequest` | 读状态做验证 |

## 合约

[`LuckyDraw.sol`](./LuckyDraw.sol)

- 继承 `VRFConsumerBaseV2Plus`（部署者是 Owner，可调用基类 `setCoordinator` 迁移 Coordinator——生产场景勿把 Owner 交给不可信方）
- `enterDraw()`：每人一次；`numWords=1`，`nativePayment=false`（用 LINK）
- 回调：`ticket = (randomWords[0] % 100) + 1`；未知 `requestId` 会 revert，并清理绑定
- 状态：未开奖 / pending / 已出结果（`1..100`）

## 本地测试

依赖：`lib/chainlink-brownie-contracts`（`@chainlink/contracts` remapping）。

```bash
cd bootcamp_2026_s3_vibe_coding_foundry
forge test --match-path 'test/chainlink_vrf/*' -vv
```

本地用官方 `VRFCoordinatorV2_5Mock`：`createSubscription` → `fundSubscription` → deploy → `addConsumer` → `enterDraw` → `fulfillRandomWords`。

## Sepolia 上线（本仓库只写步骤，不强制本轮跑通链上）

Sepolia 默认配置（与 [官方 Getting Started](https://docs.chain.link/vrf/v2-5/getting-started) 一致）：

| 项 | 值 |
|----|-----|
| Coordinator | `0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B` |
| keyHash（500 gwei lane） | `0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae` |
| callbackGasLimit | `100000`（本回调很轻；官方 Getting Started 示例用 `40000`，留余量更稳） |

### 费用注意（重要）

- `enterDraw()` **对任意地址开放**：每个新地址都能发起一次计费请求，从你的 Subscription 扣 LINK。
- 演示时只充少量 LINK；不要把高余额订阅挂到公开 consumer 上。
- 若要私密抽奖，再加 `onlyOwner` / allowlist（本 demo 刻意不加，便于任何人上手测）。

步骤：

1. [faucets.chain.link/sepolia](https://faucets.chain.link/sepolia) 领 Sepolia ETH + LINK
2. [vrf.chain.link](https://vrf.chain.link) 建 Subscription，并充 **少量** LINK
3. 部署（把 subscription id 放进环境变量，**不要提交进仓库**）：

```bash
export VRF_SUBSCRIPTION_ID=<your-sub-id>
forge script script/chainlink_vrf/DeployLuckyDraw.s.sol --broadcast \
  --rpc-url sepolia \
  --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

4. 在 Subscription Manager 把 `LuckyDraw` 地址 **Add consumer**
5. 调 `enterDraw()`，等几分钟后 `getTicket(yourAddress)` 读 `1..100`

可选覆盖：`VRF_COORDINATOR` / `VRF_KEY_HASH` / `VRF_CALLBACK_GAS`。

## 刻意不做

- 不做 Direct Funding 第二套合约
- 不做前端
- 不把真实 `subscriptionId` / 私钥写进仓库
