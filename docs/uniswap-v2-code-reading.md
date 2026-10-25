# Uniswap V2 代码阅读路线

对着本仓库 `src/uniswapv2/` 读。这是适配到 Solidity `^0.8.24` 的 fork，不是主网那份 `0.5.16` / `0.6.6` 字节码。恒定乘积、`997/1000`、TWAP 积分这些公式已经写在：

- `src/uniswapv2/docs/UniswapV2Library.md`：`quote`、`getAmountOut`、`getAmountIn`
- `src/uniswapv2/docs/UniswapV2Pair.md`：`_update`、协议费 `_mintFee`、swap 的 K 校验
- `src/uniswapv2/README.md`：文件依赖和最短阅读顺序
- `src/flash_swap/README.md`：直接调 `Pair.swap` 的闪电兑换

下面只标**先打开哪个函数、调用方要先把什么转进 Pair、这个 fork 和主网字节码哪里不一样**。

---

## 先看哪、先跳过哪

| 先读 | 作用 |
| --- | --- |
| `UniswapV2Factory.sol` | `create2` 建池，`token0 < token1`，`feeTo` |
| `UniswapV2Pair.sol` | 储备、LP、`mint` / `burn` / `swap` |
| `libraries/UniswapV2Library.sol` | 不发调用就算 pair 地址，以及询价 |
| `UniswapV2Router02.sol` | 用户入口：先转币，再调 Pair |
| `UniswapV2ERC20.sol` | LP token 和 `permit` |
| `libraries/UQ112x112.sol` | TWAP 用的定点除法，只看 `encode` / `uqdiv` |

先跳过：`interfaces/V1/*`、`IUniswapV2Migrator.sol`、`examples/`。`examples/` 仍是上游 `pragma 0.6.6`，import 的是 `@uniswap/v2-core`，不是这份 `^0.8.24` 的 Pair。本仓库里能跟着跑的 TWAP / 闪电兑换在 `src/flash_swap/`。

`SafeMath.sol` 在 0.8 里是重复的检查，遇到 `using SafeMath` 知道它会 revert 即可。时间戳那次减法专门放进了 `unchecked`，见 Pair.`_update`。

---

## 和 V3 对照着记的三件事

V3 的池子在 `swap` / `mint` 回调里向调用方要钱。V2 的 Pair 在普通兑换里不回调付款。Router 必须先把 token 转到 Pair，再调 `mint` 或 `swap`。Pair 用「现在的余额 − 账上的储备」反推这次进来了多少。`data` 非空时才会 `uniswapV2Call`，那是闪电兑换。

V3 的头寸是 NFT 上的一段 tick。V2 的头寸是 Pair 自己发行的 ERC20（LP）。加池得到 LP，撤池把 LP 转回 Pair 再 `burn`。

V3 用 `feeGrowth` 把手续费记在每个头寸上，`collect` 再转出。V2 的 0.3% 留在池子里，直接把 `k` 抬高，LP 按份额分享，没有单独的手续费领取函数。协议若要抽成，是在下次 `mint` / `burn` 时给 `feeTo` 铸新 LP。

---

## 阅读顺序

### 1. 建池：CREATE2，构造函数里只有 factory

读 `UniswapV2Factory.createPair`。

两个 token 按地址排序成 `token0 < token1`。salt 是 `keccak256(abi.encodePacked(token0, token1))`。部署用的是 `type(UniswapV2Pair).creationCode`，构造参数为空。Pair 构造函数只做一件事：`factory = msg.sender`。`token0` / `token1` 在下一行 `initialize` 里写，而且 `initialize` 只接受 factory。

`getPair` 正反两个方向都写入。`allPairs` 是枚举用的数组，算地址用不到它。

`UniswapV2Library.pairFor` 用同一套公式，init code hash 是 `keccak256(type(UniswapV2Pair).creationCode)`，随这次编译变化。主网 Router 里那份写死的 hash 对不上这个 fork。改 Pair 源码或编译器设置之后，已经部署的 Factory 算出的地址会和 `pairFor` 分叉，因为两边的 creation code 不再相同。

### 2. 储备存在哪

打开 `UniswapV2Pair` 前 50 行。`reserve0`、`reserve1`、`blockTimestampLast` 打在一个 slot 里（112 + 112 + 32）。对外只通过 `getReserves` 读。

储备不是余额。`skim` 把 `balance - reserve` 转走，`sync` 把储备改成当前余额。正常路径里，只有 `_update` 在 `mint` / `burn` / `swap` 末尾把储备写成当时的余额。

`lock` 是 `unlocked == 1` 的互斥。`mint`、`burn`、`swap`、`skim`、`sync` 都挂了它。flash 回调发生在 `swap` 里面，锁是关的，回调里再进这五个函数会 `LOCKED`。

### 3. 加池：先转币，再 `mint`

`UniswapV2Router02.addLiquidity`：

```text
_addLiquidity
  getPair == 0 → Factory.createPair
  reserves 都是 0 → 用 amountDesired
  否则 quote 对齐比例，卡 amountMin
pairFor
transferFrom(tokenA, user, pair, amountA)
transferFrom(tokenB, user, pair, amountB)
Pair.mint(to)
```

`quote` 没有手续费，只按储备比例换算另一边。公式在 Library 文档里。Router 只把算出来的 `amountA` / `amountB` 转进去，`amountDesired` 里没用掉的部分留在用户地址，不会多扣。

`Pair.mint` 不接收数量参数。它读余额，减去旧储备，得到 `amount0` / `amount1`：

- 首池：`liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY`，`MINIMUM_LIQUIDITY`（1000）铸给 `address(0)`，永久锁住。
- 之后：`min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1)`。多出来的那一边留在池子里，铸出的 LP 按少的那边算。`_mintFee` 可能先改 `totalSupply`，所以比例用的是调用 `_mintFee` 之后再缓存的 `_totalSupply`。

`addLiquidityETH` 多两步：`WETH.deposit` 后把 WETH 转进 Pair；`msg.value` 没用完的 ETH 退回 `msg.sender`。`receive` 只接受来自 WETH 的 ETH。

### 4. 撤池：LP 先转到 Pair 自己

`removeLiquidity` 把 LP `transferFrom` 到 Pair，再 `burn(to)`。`burn` 看的是 `balanceOf[address(this)]`，不是参数里的数量。按这个 LP 占 `totalSupply` 的比例，用当时的余额算出 `amount0` / `amount1`，转给 `to`，再 `_update`。

`removeLiquidityETH` 的 `to` 先写成 Router 自己，burn 把 token 和 WETH 打到 Router，再 `withdraw` 把 ETH 转给用户。滑点是 burn 之后用 `amountAMin` / `amountBMin` 卡。

`removeLiquidityWithPermit` 在转 LP 之前调 Pair 的 `permit`。LP 的 EIP-2612 在 `UniswapV2ERC20.permit`。

### 5. Swap：乐观转出，再用余额反推输入

先读 `UniswapV2Library.getAmountOut` / `getAmountsOut`，再读 `Router.swapExactTokensForTokens` 和 `Pair.swap`。

Router 的 exact input：

```text
amounts = getAmountsOut(factory, amountIn, path)
require(最后一跳 >= amountOutMin)
transferFrom(path[0], user, 第一跳 pair, amounts[0])
_swap(amounts, path, to)
```

`_swap` 沿 `path` 循环。每一跳已经知道输出量 `amounts[i + 1]`。`input == token0` 时 `amount0Out = 0`、`amount1Out = amountOut`，反方向相反。中间跳的 `to` 是下一跳的 pair 地址，最后一跳才是用户。`data` 传的是空字节，所以不会进 flash 回调。exact output 用 `getAmountsIn`，检查的是 `amounts[0] <= amountInMax`，转账和 `_swap` 的形状相同。

`Pair.swap` 自己的顺序：

1. 至少一个 `amountOut > 0`，且小于对应储备。`to` 不能是两个 token 地址。
2. 先把输出转给 `to`。`data.length > 0` 时调用 `to.uniswapV2Call`。
3. 再读余额。`amountIn` 是「余额 −（旧储备 − 已转出）」里多出来的部分。
4. `balance * 1000 - amountIn * 3` 的乘积必须 ≥ 旧 `k * 1000^2`。这就是 0.3%。推导在 `UniswapV2Pair.md`。
5. `_update` 把储备写成新余额。

Pair 不使用 Router 传来的输入数量。谁往池子里转了够的 token，谁就能通过 K 检查。Router 的滑点检查发生在调用 `swap` 之前，用的是当时的储备。Pair 保证这笔记账之后 `k` 没有变小。

ETH 路径在进第一跳之前 `WETH.deposit`，出最后一跳时如果输出是 WETH，Router 先让 pair 把 WETH 打给自己，再 `withdraw`。看 `swapExactETHForTokens` 和 `swapExactTokensForETH`。

### 6. 协议费和 TWAP

`_mintFee` 只在 `mint` / `burn` 里调用，`swap` 不铸协议 LP。`Factory.feeTo != address(0)` 时，用 `kLast` 和当前 `sqrt(reserve0 * reserve1)` 的差，按 `totalSupply * (rootK - rootKLast) / (rootK * 5 + rootKLast)` 给 `feeTo` 铸 LP。`feeTo` 被设回 0 时，下次 mint/burn 把 `kLast` 清掉。开关在 `setFeeTo`，只有 `feeToSetter` 能调。

`_update` 在储备写入之前，用旧储备累加 `price0CumulativeLast` / `price1CumulativeLast`。同一个 `block.timestamp` 里 `timeElapsed == 0`，不累加。`uint32` 时间戳回绕的减法在 `unchecked` 里，说明在 `UniswapV2Pair.md` 开头。读 TWAP 的例子看 `libraries/UniswapV2OracleLibrary.sol` 的 `currentCumulativePrices`，以及 `src/flash_swap/PoolATwapOracle.sol`。累计值是 `uint256`，预言机用两次读数之差，回绕之后差仍然是这段增量。

### 7. 转账扣费和闪电兑换

`swapExactTokensForTokens` 事先把每一跳的 `amounts[i]` 算死。输入 token 如果在 `transfer` 里扣费，Pair 实际收到的会小于这个数，K 检查会失败。`*SupportingFeeOnTransferTokens` 不走这条：先把 `amountIn` 转进第一跳，每一跳用 `balanceOf(pair) - reserve` 当真实输入，再 `getAmountOut`。最后用接收方余额的增量卡 `amountOutMin`。

闪电兑换走 `Pair.swap` 的 `data`。Pair 先把 token 转出，再 `uniswapV2Call`，回调返回后仍然做同一次 K 检查。还款就是在回调里把另一种 token 转回 Pair。本仓库的完整路径在 `src/flash_swap/FlashSwapArbitrage.sol`，不经过 Router。`examples/ExampleFlashSwap.sol` 是上游示例，不要把它当成这份 0.8 代码的入口。

---

## 四条链

建池：

```text
Router._addLiquidity
  → Factory.createPair
      → create2(Pair.creationCode, salt = keccak256(token0, token1))
      → Pair.initialize(token0, token1)
```

加池：

```text
Router.addLiquidity
  → quote 对齐 amountA / amountB
  → transferFrom 两种 token 到 pair
  → Pair.mint(to)
      → amount = balance - reserve
      → _mintFee → 铸 LP → _update
```

exact input 两跳：

```text
Router.swapExactTokensForTokens
  → getAmountsOut
  → transferFrom(path[0], user, pair0, amountIn)
  → pair0.swap(输出打给 pair1, data 为空)
  → pair1.swap(输出打给用户, data 为空)
```

撤池：

```text
Router.removeLiquidity
  → pair.transferFrom(user, pair, liquidity)
  → pair.burn(to)
      → 按 Pair 自己持有的 LP / totalSupply 分余额
      → 转出 token → _update
```

---

## 读的时候对一下

1. `mint` / `burn` / `swap` 的数量都以余额为准。调用前没把 token 或 LP 转进 Pair，函数会算成 0 并 revert。
2. 首池锁进 `address(0)` 的 1000 LP 不会回到任何人手里。`sqrt(amount0 * amount1)` 必须大于 1000。
3. 后续加池取两边比例的较小值。多转的那一边变成池子余额，`_update` 之后算进储备，等于送给现有 LP。
4. `burn` 按余额而不是储备分配。`skim` 之前捐赠进池子的 token，会在撤池时被 LP 按份额拿走。
5. `swap` 可以两边都有输出，只要回调或调用方在检查 K 之前把输入补上。Router 的 `_swap` 每次只让一边非零。
6. 中间跳的收款人是下一跳 Pair，不是 Router。Router 不经手中间 token。
7. `pairFor` 不读 `Factory.getPair`。池子还没 `createPair` 时它也会算出一个地址，向那个地址转账会失败。
8. `examples/` 的编译目标和 import 都不是这个目录。跟着测试跑用 `test/uniswapv2/UniswapV2Router02.t.sol` 和 `src/flash_swap/`。

---

## 建议的四天

| 天 | 读完应该能指着代码讲清楚 |
| --- | --- |
| 1 | `createPair`、`pairFor`、`getReserves`。为什么改 Pair 源码会让地址对不上 |
| 2 | `addLiquidity` → `mint`，含首池 1000 LP 和后续 `min` 比例 |
| 3 | `swapExactTokensForTokens` → `_swap` → `Pair.swap` 的乐观转出和 K 检查 |
| 4 | `removeLiquidity` / `removeLiquidityETH`，再选协议费或 `src/flash_swap` 其中一条走完 |

公式卡在某一行时，打开 `src/uniswapv2/docs/UniswapV2Library.md` 或 `UniswapV2Pair.md` 的对应小节。
