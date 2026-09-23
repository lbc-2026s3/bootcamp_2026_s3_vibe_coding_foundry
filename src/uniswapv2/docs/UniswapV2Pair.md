# UniswapV2Pair 说明

对应实现：[`UniswapV2Pair.sol`](./UniswapV2Pair.sol)。

Pair 是 V2 的核心池子：持有 `token0` / `token1`，发行 LP（继承 `UniswapV2ERC20`），提供 `mint` / `burn` / `swap`。用户通常经 Router 调用。

- swap **询价**（Library）：[`libraries/UniswapV2Library.md`](./libraries/UniswapV2Library.md)
- 本文：**`_update` / TWAP**、**协议费 `_mintFee`**、**swap 的 K 校验**

---

## `_update`：写储备 + TWAP 累加

`mint` / `burn` / `swap` / `sync` 末尾都会调用 `_update(balance0, balance1, _reserve0, _reserve1)`。

### 储备上限

```solidity
require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');
```

`reserve0` / `reserve1` 是 `uint112`（与 `blockTimestampLast` 共用一个 storage slot）。余额更大则不能写入。

### 时间差 `timeElapsed`

```solidity
uint32 blockTimestamp = uint32(block.timestamp % 2**32);
timeElapsed = blockTimestamp - blockTimestampLast; // unchecked
```

- 正常：`timeElapsed` = 距上次更新的秒数。
- **同一区块内第二次 `_update`**：`blockTimestamp == blockTimestampLast` → `timeElapsed = 0`，**本块不再累加 TWAP**（每块最多积一次）。
- `unchecked`：与官方 V2 一致，允许 `uint32` 时间戳回绕时的减法语义。

### TWAP 累加（`price0CumulativeLast` / `price1CumulativeLast`）

当 `timeElapsed > 0` 且池子非空时，用 **更新前** 的储备 `_reserve0` / `_reserve1`：

```text
price0CumulativeLast += (reserve1 / reserve0) * timeElapsed   // 价格0：token1  per token0
price1CumulativeLast += (reserve0 / reserve1) * timeElapsed   // 价格1：token0  per token1
```

实现用 `UQ112x112.encode(...).uqdiv(...)` 做定点小数，再乘 `timeElapsed`。

**用途**：TWAP 预言机，**不是** Router `getAmountOut` 算换币量。

| 变量 | 含义 |
|------|------|
| `price0CumulativeLast` | 价格0（`token1 / token0`）对时间的积分 |
| `price1CumulativeLast` | 价格1（`token0 / token1`）对时间的积分 |

读出 TWAP（两个时刻 \(t_0, t_1\)）：

\[
\text{TWAP} = \frac{priceCumulative_{t_1} - priceCumulative_{t_0}}{t_1 - t_0}
\]

- **现货价** `reserve1/reserve0`：单笔 swap 可操纵。
- **TWAP**：需长时间顶价，更适合借贷/清算等预言机输入。

### 谁在消费累加器？

| 路径 | 作用 |
|------|------|
| [`libraries/UniswapV2OracleLibrary.sol`](./libraries/UniswapV2OracleLibrary.sol) | `currentCumulativePrices(pair)`：读累加器；本块若尚未 `_update`，用储备反事实补到当前 |
| [`examples/ExampleOracleSimple.sol`](./examples/ExampleOracleSimple.sol) | 固定窗口 TWAP（如 24h） |
| [`examples/ExampleSlidingWindowOracle.sol`](./examples/ExampleSlidingWindowOracle.sol) | 滑动窗口 TWAP |

> `examples/*`、`UniswapV2OracleLibrary.sol`、`UniswapV2LiquidityMathLibrary.sol` 为旧 `pragma`（0.5–0.6），已在 `foundry.toml` 的 `skip` 中排除；学习可读源码，接入编译需再适配。

### 相关

- `blockTimestampLast`：与 reserve 同 slot，算 `timeElapsed`。
- `Sync` 事件：发出更新后的 `reserve0` / `reserve1`；累加器需读 public 变量。

---

## 协议费 `_mintFee`（`feeTo`）

在 **`mint` / `burn` 开头**调用。Factory 的 `feeTo != 0` 时开启协议费。

### 机制

- 每笔 swap 约 **0.3%** 留在池里 → \(k = reserve0 \times reserve1\) 变大，但 **LP 总供应不变**。
- 下次有人 **加池或撤池** 时，把自上次记录的 `kLast` 以来 \(\sqrt{k}\) 的增长里，约 **1/6** 用 **新铸 LP** 发给 `feeTo`；其余约 5/6 仍体现在「同样 LP 能换更多 token」里。

### 条件

| 条件 | 含义 |
|------|------|
| `feeTo != address(0)` | 协议费打开 |
| `kLast != 0` | 上次 mint/burn 后写过 `kLast`；首池尚无基准则跳过 |
| `rootK > rootKLast` | 中间有 swap 把 \(k\) 抬高 |

```text
rootK     = sqrt(reserve0 * reserve1)
rootKLast = sqrt(kLast)
```

### 公式

\[
liquidity = totalSupply \times \frac{rootK - rootKLast}{rootK \times 5 + rootKLast}
\]

若 `liquidity > 0`，`_mint(feeTo, liquidity)`。分母里的 **5** 来自「手续费增长中约 1/6 归协议、5/6 归现有 LP」的份额设计（V2 白皮书）。

`feeTo == 0` 时：`kLast = 0`，关闭协议费。

mint/burn 末尾若 `feeOn`：`kLast = reserve0 * reserve1`（用更新后的储备作下一轮基准）。

---

## `swap` 里的 K 校验（0.3% 手续费）

swap 先 **乐观转出** `amount0Out` / `amount1Out`，再读余额反推 `amount0In` / `amount1In`，最后校验恒定乘积（**输入只计 997/1000**）。

swap 前：\(k = \_reserve0 \times \_reserve1\)。

```solidity
balance0Adjusted = balance0 * 1000 - amount0In * 3
balance1Adjusted = balance1 * 1000 - amount1In * 3
require(balance0Adjusted * balance1Adjusted >= _reserve0 * _reserve1 * 1000**2, 'UniswapV2: K');
```

### 含义

0.3% = **3/1000**，只对 **输入** 抽费。有效余额（整数形式）：

\[
\left(balance0 - \frac{3}{1000}\, amount0In\right)\left(balance1 - \frac{3}{1000}\, amount1In\right) \ge \_reserve0 \cdot \_reserve1
\]

`balance` 含 100% 输入；真正推高 \(k\) 的只有 **997/1000** 的输入，故减去 `amountIn * 3`（两侧乘 1000^2 避免小数）。

### 与 Library 的关系

| | |
|--|--|
| `UniswapV2Library.getAmountOut` | Router **询价**（997/1000） |
| Pair `K` | 链上 **强制执行**；不满足则 `UniswapV2: K` revert |

---

## `mint` 流动性（简要）

调用前须先把 token **转入** Pair；增量 = `balance - reserve`。

| 场景 | LP 数量 |
|------|---------|
| 首池（`totalSupply == 0`） | `sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY`；`MINIMUM_LIQUIDITY` 铸给 `address(0)` 永久锁定 |
| 后续 | `min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1)`，按较小比例避免稀释另一边 |

流程：`_mintFee` → 给用户 `_mint(to, liquidity)` → `_update` → 若 `feeOn` 更新 `kLast`。
