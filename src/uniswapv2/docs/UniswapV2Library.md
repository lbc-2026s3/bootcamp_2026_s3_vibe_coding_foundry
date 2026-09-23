# UniswapV2Library 公式说明

对应实现：[`UniswapV2Library.sol`](./UniswapV2Library.sol)。

核心是 **恒定乘积** \(x \cdot y = k\)，swap 时对输入抽 **0.3%** 手续费（等价于输入先乘 \(997/1000\)）。

## `quote`（无手续费）

按储备比例换算。**加池 = 添加流动性**（`Router.addLiquidity` / `addLiquidityETH`），不是 swap 询价。

池子里已有比例 `reserveA : reserveB`。你想再投一边 `amountADesired` 时，Router 用 `quote` 算出另一边该投多少，才能跟现有比例对齐，避免多塞的一侧被浪费：

\[
amountB = amountA \times \frac{reserveB}{reserveA}
\]

对应 Router 里常见写法：`amountBOptimal = quote(amountADesired, reserveA, reserveB)`。

首池（两边储备都是 0）没有比例可跟，不用 `quote`，直接按你提交的两边数量建池。

| 函数 | 公式本质 | 用途 | 手续费 |
|------|----------|------|--------|
| `quote` | 比例换算 | **添加流动性**时对齐双边数量 | **无** |
| `getAmountOut` / `getAmountIn` | 恒定乘积 + 滑点 | **换币（swap）** 询价 | **有 0.3%** |

## `getAmountOut`：已知投入 → 最多换出多少

换前：`reserveIn * reserveOut = k`。  
投入 `amountIn` 后，实际计入池子的是扣费后的量：

\[
\Delta x' = amountIn \times \frac{997}{1000}
\]

换后仍满足：

\[
(reserveIn + \Delta x') \times (reserveOut - amountOut) = reserveIn \times reserveOut
\]

解出：

\[
amountOut = \frac{\Delta x' \times reserveOut}{reserveIn + \Delta x'}
\]

合约里为避免浮点，分子分母同乘 1000：

```text
amountInWithFee = amountIn * 997
numerator       = amountInWithFee * reserveOut
denominator     = reserveIn * 1000 + amountInWithFee
amountOut       = numerator / denominator
```

**小例子**：池子 100 ETH / 200_000 USDC，卖 1 ETH：

\[
amountOut = \frac{1 \times 997 \times 200000}{100 \times 1000 + 1 \times 997} \approx 1984\ \text{USDC}
\]

（不是按现价 2000，因为有滑点 + 手续费。）

## `getAmountIn`：已知想拿到多少 → 最少要投入多少

和上面同一套恒定乘积，只是 **已知 `amountOut`，反解 `amountIn`**。

换前：`reserveIn * reserveOut = k`。  
设实际计入池子的扣费后输入为 \(\Delta x' = amountIn \times 997/1000\)，换后仍要：

\[
(reserveIn + \Delta x') \times (reserveOut - amountOut) = reserveIn \times reserveOut
\]

展开左边：

\[
reserveIn \times (reserveOut - amountOut) + \Delta x' \times (reserveOut - amountOut)
= reserveIn \times reserveOut
\]

移项，只留含 \(\Delta x'\) 的项：

\[
\Delta x' \times (reserveOut - amountOut)
= reserveIn \times reserveOut - reserveIn \times (reserveOut - amountOut)
= reserveIn \times amountOut
\]

因此：

\[
\Delta x' = \frac{reserveIn \times amountOut}{reserveOut - amountOut}
\]

再把 \(\Delta x' = amountIn \times 997/1000\) 代回去，解 `amountIn`：

\[
amountIn \times \frac{997}{1000} = \frac{reserveIn \times amountOut}{reserveOut - amountOut}
\]

\[
amountIn = \frac{reserveIn \times amountOut \times 1000}{(reserveOut - amountOut) \times 997}
\]

合约里还要 **`+ 1`**：整数除法向下取整，结果可能偏小 1 wei；少付会导致 Pair `swap` 的 `K` 校验失败，所以向上补 1：

\[
amountIn = \frac{reserveIn \times amountOut \times 1000}{(reserveOut - amountOut) \times 997} + 1
\]

对应代码：

```text
numerator   = reserveIn * amountOut * 1000
denominator = (reserveOut - amountOut) * 997
amountIn    = numerator / denominator + 1
```

和 `getAmountOut` 对照：一个正着解输出，一个反着解输入；方程相同，未知数不同。

## `getAmountsOut` / `getAmountsIn`（多跳）

把单跳串起来：

```text
path = [A, B, C]

getAmountsOut:  A→B 用 getAmountOut，再 B→C 用 getAmountOut
                amounts[0]=amountIn, amounts[last]=最终输出

getAmountsIn:   先定 C 的目标输出，从后往前 B←C、A←B 各算一次 getAmountIn
                amounts[last]=amountOut, amounts[0]=所需总输入
```

`amounts.length == path.length`：每一跳边界上的数量。

## 一句话

- `997/1000` = 手续费  
- 公式里的 `1000` = 与 `997` 对齐做整数运算  
- `getAmountOut` 正着解输出；`getAmountIn` 反着解输入并 `+1` 防截断  
