# CheckpointLedger — OpenZeppelin Checkpoints 示例

演示 [`Checkpoints.Trace208`](https://docs.openzeppelin.com/contracts/5.x/api/utils#Checkpoints) 的典型用法（与 `ERC20Votes` 同款）。

## 在做什么

每次 `mint` / `burn` / `transfer` 都会以 **当前 `block.number` 为 key** 写入一条 checkpoint，从而可以事后查询：

- `balanceOfAt(account, blockNumber)` — 某账户在历史区块的余额
- `totalSupplyAt(blockNumber)` — 历史总供给

## 核心 API（OZ）

| 方法 | 作用 |
|---|---|
| `push(key, value)` | 写入 checkpoint；同 key 则覆盖 |
| `latest()` | 最新 value |
| `upperLookupRecent(key)` | ≤ key 的最近 value（查历史） |
| `length()` / `pos(i)` | 遍历 checkpoint 列表 |

## 注意

1. **key 必须非递减**（用 `block.number` / `clock()` 即可）；不要把用户任意输入当 key。
2. **同一区块多次写入只保留最后一次**。
3. Trace208 的 value 上限是 `uint208`；更大数值用 `Trace256`。

## 部署

```bash
forge script script/checkpoint/DeployCheckpointLedger.s.sol:DeployCheckpointLedger \
  --broadcast --rpc-url local \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  && cat ./deployments/LATEST.txt
```
