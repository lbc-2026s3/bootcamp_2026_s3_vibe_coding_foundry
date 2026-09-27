# Rebase 通缩 Token

每年在上一年供给基础上通缩 **1%**。持仓用份额记账，`rebase()` 只改总供给；`balanceOf` 按份额占比读出通缩后余额。

## 核心公式

```
balanceOf(user) = sharesOf(user) × totalSupply / totalShares
rebase 后：totalSupply ← totalSupply × 99 / 100（份额不变）
```

## 参数

| 项 | 值 |
|---|---|
| 初始发行量 | 1_000_000 × 10^18（100 万枚） |
| 通缩 | 每年 1% |
| 周期 | 365 days |
| 接收人 | 构造参数 `recipient`（部署脚本铸给 deployer） |

## 用法

```bash
# 测试
forge test --match-path test/rebase/RebaseToken.t.sol -vv

# 本地部署
forge script script/rebase/DeployRebaseToken.s.sol:DeployRebaseToken \
  --broadcast --rpc-url local \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

满一年后（或模拟 `vm.warp`）调用 `rebase()`。若多年未调用，一次可追上全部到期年份。
