# OptionToken — ETH 看涨期权

以 **ETH** 为标的的 covered call 期权，本身是 ERC20。项目方存入 ETH 按 **1:1** 发行期权 Token；到期日当天持有人用 **USDT** 按行权价兑换 ETH；窗口结束后项目方赎回剩余抵押 ETH。

## 流程

```
部署（锁定 strikePrice + expiry）
    │
    ▼
issue()：项目方转入 ETH → 铸造等量期权（到期日前）
    │
    ▼  （项目方把期权卖给/转给用户）
    │
到期日当天 [expiry, expiry + 1 days)
    │
    ▼
exercise(amount)：用户付 USDT → 烧期权 → 领等量 ETH
    │
    ▼
expireAndRedeem()：到期日结束后，项目方烧自持剩余期权，取回合约内全部 ETH
```

## 核心公式

```
行权成本（USDT）= optionAmount × strikePrice / 1e18
期权数量与 ETH 抵押 1:1（同为 wei 精度）
```

例：USDT 为 6 decimals、行权价 2000 USDT/ETH 时，`strikePrice = 2000e6`；行权 `2 ether` 期权需付 `4000e6` USDT。

## 参数

| 项 | 说明 |
|---|---|
| 标的 | 原生 ETH |
| 行权支付币 | `usdt`（测试用 6 decimals MockUSDT） |
| `strikePrice` | 兑换 1 ETH 所需的 USDT 最小单位数量 |
| `expiry` | 到期日起始时间戳 |
| 行权窗口 | `[expiry, expiry + 1 days)` |
| 角色 | `issue` / `expireAndRedeem` 仅 owner；`exercise` 任意持有人 |

## 过期说明

行权窗口结束后，用户未行权的期权失效（无法再 `exercise`）。合约无法强行烧掉他人钱包里的 Token，只烧掉项目方自持部分；对应未行权的 ETH 抵押品通过 `expireAndRedeem` 全部归还项目方。

## 用法

```bash
# 测试
forge test --match-path test/option/OptionToken.t.sol -vv

# 本地部署（未设 USDT 时会顺带部署 MockUSDT）
forge script script/option/DeployOptionToken.s.sol:DeployOptionToken \
  --broadcast --rpc-url local \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  && cat ./deployments/LATEST.txt
```

可选环境变量：`USDT`、`STRIKE_PRICE`（默认 `2000e6`）、`EXPIRY`（默认 now + 30 days）。
