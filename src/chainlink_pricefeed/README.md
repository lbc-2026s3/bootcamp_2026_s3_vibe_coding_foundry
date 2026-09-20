# Chainlink Data Feed PriceConsumer Demo

用一个极简合约演示 [Chainlink Data Feeds](https://docs.chain.link/data-feeds/using-data-feeds)：**DON 把价格写上链 → 业务合约读 proxy 的 `latestRoundData()`**。

## 心智模型（合约为什么不能自己查价格）

智能合约没有 HTTP、没有 Google。链下价格必须由预言机写上链，业务合约才能读。

**不要用 DEX 现货价当预言机**：闪电贷可以在同一笔交易里操纵池子价格。Chainlink Data Feed 是独立聚合后再上链的。

```text
Chainlink DON                 ETH/USD Proxy (AggregatorV3)
     │                                    ▲
     │── heartbeat / 偏差更新 ─────────────┘
                                          ▲
User / 任何合约 ── latestRoundData() ─────┘
```

| 谁调用 | 做什么 |
|--------|--------|
| Chainlink DON | 更新 Aggregator（本合约不参与、不付 LINK） |
| 任何人 `getLatestPrice()` | 读价；过期 / 非正价格会 revert |
| 任何人 `getEthValueInUsd(wei)` | 把 ETH 换成 USD（精度 = feed decimals，ETH/USD 通常为 8） |

无人调用 view 函数时系统不会坏：价格由 DON 维护，不是本合约的定时任务。

## 合约

[`PriceConsumer.sol`](./PriceConsumer.sol)

- 构造函数注入 **proxy 地址** + **heartbeat**（不写死 feed，便于 Sepolia / 主网 / mock）
- 读 `latestRoundData()`，不用已弃用的 `latestAnswer()`
- 新鲜度只看 `updatedAt`，不用已弃用的 `answeredInRound`
- 始终读 proxy，不直连底层 aggregator

校验：

- `answer > 0`
- `updatedAt != 0` 且 `updatedAt + heartbeat >= block.timestamp`
- heartbeat 必须在 `(0, 7 days]`

换算：`usd = wei * uint256(answer) / 1e18`（先乘后除）。1 ETH、answer = `2000e8` → `2000e8`（$2000.00000000）。

## 本地测试

依赖：`lib/chainlink-brownie-contracts`（`@chainlink/contracts` remapping）。

```bash
cd bootcamp_2026_s3_vibe_coding_foundry
forge test --match-path 'test/chainlink_pricefeed/*' -vv
```

- 单元测试用官方 `MockV3Aggregator`：正常读价、零/负价格、过期、heartbeat 边界、fuzz 换算
- 主网 fork 测试（需要 `.env` 里 `FOUNDRY_RPC_ENDPOINTS` 配了 `mainnet`）：钉在区块 `25925858`，读真实 ETH/USD `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`。没有 RPC 时自动 skip

## Sepolia 上线（本仓库只写步骤，不强制本轮跑通链上）

Data Feed **不收 LINK**（和 VRF 不同）。

Sepolia 默认配置（与 [官方 API Reference](https://docs.chain.link/data-feeds/api-reference) 一致）：

| 项 | 值 |
|----|-----|
| ETH/USD proxy | `0x694AA1769357215DE4FAC081bf1f309aDC325306` |
| heartbeat | `24 hours`（testnet 更新可能比主网 3600s 慢） |

步骤：

1. 确认 `.env` 有 `SEPOLIA_PRIVATE_KEY` 和 sepolia RPC
2. 部署：

```bash
forge script script/chainlink_pricefeed/DeployPriceConsumer.s.sol --broadcast \
  --rpc-url sepolia \
  --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

3. 读价：

```bash
cast call <PriceConsumer> "getLatestPrice()" --rpc-url sepolia
cast call <PriceConsumer> "getEthValueInUsd(uint256)" 1ether --rpc-url sepolia
```

可选覆盖：`PRICE_FEED` / `PRICE_HEARTBEAT`。

主网 ETH/USD（仅 fork / 生产查阅，本 demo 默认不部署主网）：`0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`。

## 刻意不做

- 不做前端
- 不做 Chainlink Functions / Data Streams
- 不用 DEX spot 当备用预言机
- 不把价格当数据库存历史
- 不托管用户资金（纯只读）
