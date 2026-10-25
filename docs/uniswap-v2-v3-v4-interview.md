# Uniswap V2 / V3 / V4 面试题

对着本仓库能开口讲的版本：

- V2：`src/uniswapv2/`，Solidity `^0.8.24` 的 fork。公式和主网一致，字节码不是主网那份。
- V3：旁边的 `uniswapv3/v3-core`、`uniswapv3/v3-periphery`。本仓库工厂构造函数只启用 `500 / 3000 / 10000` 三档。
- V4：这个工作区没有源码。下面的标志位、delta 符号、手续费上限以已发布的 [Uniswap v4-core](https://github.com/Uniswap/v4-core) 为准（`src/libraries/Hooks.sol`、`src/PoolManager.sol`、`src/libraries/LPFeeLibrary.sol`、`src/libraries/ProtocolFeeLibrary.sol`），不是 2023 年草稿里的 `beforeModifyPosition`。

代码怎么往下走，看 `docs/uniswap-v2-code-reading.md` 和 `docs/uniswap-v3-code-reading.md`。这份只练口述。每题先给结论，再给不变量或公式，最后给追问时要补上的边界。

---

## 60 秒对照

| | V2 | V3 | V4 |
| --- | --- | --- | --- |
| 池子在哪 | 每个交易对一个 `Pair` 合约 | 每个交易对 + 费率一个 `Pool` 合约 | 全部池子的状态在一个 `PoolManager` 里 |
| 曲线 | 全区间 `x * y = k` | 当前价格所在区间内，虚拟储备满足 `x * y = L^2` | 默认同一套集中流动性。hook 返回的 delta 可以改结算 |
| 头寸 | Pair 自己发行的 ERC20 | core：`owner + tickLower + tickUpper`。用户手里通常是 NFT | `owner + tickLower + tickUpper + salt`。`PositionManager` 用 tokenId 当 salt |
| 交易者付的费 | 固定 0.3% | 池子的 `fee`，单位是 hundredths of a bip：`3000` = 0.30% | 静态费，或 `fee == 0x800000` 的动态费。协议费先从输入里扣 |
| 费记在哪 | 留在池子里，把 `k` 抬高。没有 `collect` | `feeGrowthGlobal`，头寸用两次快照的差，`collect` 才转出 | 同一套 fee growth。还可以 `donate` 给当前价格内的 LP |
| 钱什么时候动 | Router 先把 token 转进 Pair，再调用 | 池子先记账，回调里向调用方要钱，再查余额 | `unlock` 里只改 delta。回调结束前必须 settle / take 到 0 |
| ETH | 换成 WETH | 换成 WETH | `address(0)` 就是原生 ETH，而且它永远是 `currency0` |
| 预言机 | `price{0,1}CumulativeLast` | 池子里的 `observations` | 核心没有。要 TWAP 就写成 hook |
| 地址怎么来 | CREATE2，salt 是两个 token | CREATE2，salt 是两个 token + fee | 没有池合约。`PoolId = keccak256(abi.encode(poolKey))` |

---

## 怎么答

四拍就够：

1. 这句话在保护哪个不变量。
2. 公式或存储字段，说出数字从哪来。
3. 落到哪个函数。V2/V3 用本仓库路径，V4 用 `PoolManager` 上的入口。
4. 补一个边界：谁付手续费、舍入偏向谁、回调时锁是什么状态。

---

## V2

### 1. `x * y = k` 在一次成交里实际检查的是什么？

检查的不是用户传入的 `amountIn`，是成交后的余额。

`Pair.swap` 先把 `amount0Out` / `amount1Out` 转走，可选地做闪电回调，再读 `balanceOf`。输入量是算出来的：

```text
amountIn = balanceNow - (reserve - amountOut)    // 余额没有盖过转出后的储备则为 0
```

然后做调整后的 K 检查（`UniswapV2Pair.swap`）：

```text
balance0Adjusted = balance0 * 1000 - amount0In * 3
balance1Adjusted = balance1 * 1000 - amount1In * 3
balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * 1000^2
```

`* 3` 是 0.3% 手续费。调整后的余额比真实余额小，K 用小的那组数来比。真实余额留下了手续费，下一笔的储备更高，`k` 变大。

0.3% 是对输入收的。两边都有输入时，两边都收。

### 2. 手写 `getAmountOut`

`UniswapV2Library.getAmountOut`：

```text
amountInWithFee = amountIn * 997
amountOut = amountInWithFee * reserveOut / (reserveIn * 1000 + amountInWithFee)
```

分子先扣费，分母把扣完费的输入加进储备。结果向下取整，余数留在池子里。

精确输出是反过来的，并且向上取整后再 `+ 1`（`getAmountIn`）。少算 1 wei 会过不了 Pair 的 K 检查。

`quote` 没有 997。它只在加池时按储备比例换算另一边，不加手续费。

### 3. 为什么普通兑换要先转账，再调用 `swap`？

Pair 不接收数量参数，也不 `transferFrom`。它只认「现在的余额 − 账上的储备」。

Router 的顺序是：`transferFrom` 用户到 Pair，再 `swap`。`data` 为空就不会回调。

这样设计以后，直接给 Pair 转一笔账，储备不会变。差额要等 `mint`、`swap`、`skim` 或 `sync` 才处理。

### 4. 闪电兑换和普通兑换差在哪？

差在 `data`。`data.length > 0` 时，乐观转出之后、K 检查之前，调用 `IUniswapV2Callee(to).uniswapV2Call`。

回调里可以把两个 token 都借走。同一笔交易结束前，Pair 的余额必须重新满足带 0.3% 费的 K。不还，整笔交易回滚。

回调发生时 `lock` 是关的。回调里再进 `mint` / `burn` / `swap` / `skim` / `sync` 会 `LOCKED`。

### 5. `skim` 和 `sync` 分别在修什么？

储备不是余额。`reserve0`、`reserve1`、`blockTimestampLast` 打在一个 slot 里（112 + 112 + 32），只有 `_update` 在 `mint` / `burn` / `swap` 末尾把储备写成当时的余额。

- `skim`：把 `balance - reserve` 转给调用者。储备不动。用来取走多转进来的 token。
- `sync`：把储备改成当前余额。有人直接往 Pair 转账、或代币余额自己变了，又希望这个差额算进池子，才用它。

`sync` 会把捐赠算进 `k`，全体 LP 分享。它也是把异常余额写进价格的入口，不要在余额不可信时调用。

### 6. 首池为什么要锁 1000 个 LP？

`MINIMUM_LIQUIDITY = 1000`，铸给 `address(0)`，拿不回来。首池流动性是：

```text
liquidity = sqrt(amount0 * amount1) - 1000
```

之后每次：

```text
liquidity = min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1)
```

锁这 1000 是为了抬高「份额相对储备」的精度下限。`totalSupply` 极小时，攻击者可以先捐赠，把储备抬得很高、份额仍极少，下一笔存款按整数除法铸出 0，再 `burn` 把存款提走。1000 股永久锁住以后，要把后来者的份额整除成 0，捐赠量得大到不划算。

它挡的是取整，不是把价格操纵从协议里删掉。

### 7. 协议费为什么公式里是 5，口头却说 1/6？

交易者始终付 0.3%。`feeTo != address(0)` 时，协议要这 0.3% 里的 1/6，LP 留 5/6。实现不在 `swap` 里转账，而在下一次 `mint` 或 `burn` 时给 `feeTo` 铸新 LP。

`_mintFee`：

```text
liquidity = totalSupply * (sqrt(k) - sqrt(kLast)) / (5 * sqrt(k) + sqrt(kLast))
```

`sqrt(k)` 变大，来自手续费留在池子里。设协议想要的份额比例是 `φ = 1/6`，铸出的 LP 占铸完后总供给的比例应等于「增长里的 1/6」。化简以后分母系数是 `(1 - φ) / φ = 5`。

`feeTo` 设回 0 时，下次 `_mintFee` 把 `kLast` 清零，增长不再结算给协议。`_mintFee` 可能先改 `totalSupply`，所以后面按比例铸 LP 用的是调用之后再缓存的 `_totalSupply`。

### 8. TWAP 为什么累加价格，而不是在合约里存一个均价？

`_update` 里，只要时间走过至少 1 秒：

```text
price0CumulativeLast += (reserve1 / reserve0) * timeElapsed
```

价格先用 `UQ112x112` 编码再除。累计值只增不改历史。调用方在两个时刻各读一次，差除以时间差就是这段时间的时间加权平均价。

池子不存窗口。窗口是阅读方选的。同一区块里第一笔成交才会把上一段价格按时间补上，本区块内的价格要等下一个区块的 `_update` 才进累计值。用当前储备当「已经成交的 TWAP」是错的。

### 9. 加池和撤池，LP 代币在谁手里？

加池：Router 把两种 token 转进 Pair，`mint(to)` 把 LP 铸给 `to`。`mint` 自己不收数量。

撤池：先把 LP `transferFrom` 到 Pair 自己，再 `burn(to)`。`burn` 看的是 `balanceOf[address(this)]`，按这个余额占 `totalSupply` 的比例，从当时的 token 余额里转出。

所以 LP 是 ERC20 份额，不是 NFT，也没有独立的手续费领取。手续费已经在储备里，撤池时一并按份额拿走。

### 10. 无常损失怎么说清楚？

相对「拿着这两种代币不动」，把它们放进全区间恒定乘积池，价格变化之后池内组合的价值更低。差的那一块就是无常损失。手续费可以把它补回来，补不回来就一直亏着。

价格变成原来的 `r` 倍时，相对持有的价值比是：

```text
2 * sqrt(r) / (1 + r) - 1
```

价格翻倍，`r = 2`，这个值约是 `-5.7%`。价格回到原处，损失消失，所以叫无常。它是再平衡的代价：涨的那种被池子卖掉，跌的那种被池子买进。

### 11. 价格影响和滑点分别卡在哪一层？

价格影响是这笔成交把自己打到曲线上的新位置，输出比「用成交前价格乘数量」少掉的那一部分。池子越浅、单笔相对储备越大，影响越大。`getAmountOut` 已经把它算进去了。

滑点是成交价相对你下单时看到的价格的偏差。来源包括你自己的价格影响、在你之前插队的成交、以及交易在 mempool 里等待时价格变了。Router 用 `amountOutMin` 和 `deadline` 卡住。Pair 自己不看这两个参数。

### 12. 重入时哪一层在保护池子？

`lock` 要求 `unlocked == 1`。`mint`、`burn`、`swap`、`skim`、`sync` 都挂了它。闪电回调在 `swap` 里面，锁已经关上。

K 检查在回调之后。攻击者不能在回调里再进 Pair 把储备改掉再回来通过检查。

这把锁不管外部代币的回调。代币在 `transfer` 里重入的是代币自己的接收者；真要再进 Pair，还是会被 `LOCKED` 挡住。

---

## V3

### 13. 集中流动性在省什么资本？

同一笔成交只跟当前价格所在区间里的流动性做交易。LP 把 `L` 放在 `[tickLower, tickUpper)`，等价于在这段价格上放了更深的虚拟储备。

资本效率来自这里：全区间的 V2 头寸，大部分储备停在远离现价的地方，这笔成交用不上。把同一数量的 token 收进更窄的区间，现价附近的 `L` 更大，同样的成交价格推得更少，每一单位 `L` 分到的手续费也更多。

价格走出区间之后，这笔头寸不再参与成交，也不再赚手续费，并且只剩一种代币。

### 14. `sqrtPriceX96` 和 tick 各表示什么？

```text
price = token1 / token0 = (sqrtPriceX96 / 2^96) ^ 2
tick = log(price) / log(1.0001)
```

`sqrtPriceX96` 是 `sqrt(price)` 的 Q64.96。用平方根，是因为区间内的数量公式是 `L` 乘 `sqrt(P)` 的差，乘法和除法就能算完，不必在合约里开方。`2^96` 把小数放进整数。

tick 是价格的对数索引。相邻 tick 的价格比是 `1.0001`，大约 1 个基点。合法范围是 `[-887272, 887272]`，对应 `sqrtPrice` 还能放进 `uint160` 的那一段。`TickMath.getSqrtRatioAtTick` 用预先算好的 `1.0001^(2^k)` 连乘，不在链上做对数。

当前 tick 是「现价落在哪个区间的下边界」。`zeroForOne` 穿过 `tickNext` 之后，tick 要写成 `tickNext - 1`，因为价格已经到了这条边界的左侧。

### 15. `L` 和 token 数量怎么换算？

`L` 不是 token 枚数。在一个价格区间里，虚拟储备满足 `x * y = L^2`，`L` 在不跨区间加仓、减仓时保持不变。

现价在区间内时，头寸两边的数量是：

```text
amount0 = L * (sqrt(upper) - sqrt(price)) / (sqrt(price) * sqrt(upper))
amount1 = L * (sqrt(price) - sqrt(lower))
```

`_modifyPosition` 按当前 tick 分三支：

| 当前 tick | 要付的 token | 价格内的 `liquidity` |
| --- | --- | --- |
| `< tickLower` | 只有 token0 | 不动 |
| `[tickLower, tickUpper)` | 两边都付 | 加上这份 `L` |
| `>= tickUpper` | 只有 token1 | 不动 |

区间在现价上方，头寸还没被买成 token1，所以全是 token0。区间在现价下方，token0 已经换成 token1。

### 16. 手续费为什么不在每笔 swap 里写每个头寸？

swap 只更新全局累计。头寸下次被碰到时再结算。

`feeGrowthGlobal{0,1}X128` 是「从初始化到现在，每一单位正处在价格内的流动性，累计分到多少手续费」，乘了 `2^128`。一步 swap 里：

```text
feeGrowthGlobal += feeAmount * 2^128 / liquidity
```

`liquidity == 0` 的区间可以走过去，这一步不加，因为没有人在里面。

每个已初始化 tick 存 `feeGrowthOutside`。头寸的区间内累计是：

```text
feeGrowthInside = global - below - above
```

头寸只存上次结算时的 `feeGrowthInsideLast`。下次 `mint`、`burn`，或者 `burn(0)` 这种 poke：

```text
tokensOwed += (insideNow - insideLast) * liquidity / 2^128
```

用的是结算前的 `liquidity`。`collect` 只减 `tokensOwed` 并转账，它自己不再读 fee growth。所以区间里已经产生、还没 poke 的手续费，直接 `collect` 拿不到。NonfungiblePositionManager 会在 `collect` 前先 `burn(..., 0)`。

`uint256` 减法溢出是预期行为。全局值绕回 0 之后，两次快照的差仍是这段增量。

### 17. `liquidityNet` 和 `liquidityGross` 各管什么？

`liquidityGross` 是把这个 tick 当边界的流动性绝对值之和。它从 0 变成非 0，或从非 0 变回 0 时，bitmap 里这个 tick 翻一次。它还受 `maxLiquidityPerTick` 限制。

`liquidityNet` 是穿过这个 tick 时价格内流动性的增量。下界 `+= delta`，上界 `-= delta`。从左向右穿过时，把 `liquidityNet` 加进当前 `liquidity`。`zeroForOne` 是从右向左，要把 `liquidityNet` 取负再加。

bitmap 存的不是流动性数值，是「这个压缩后的 tick 有没有被初始化」。swap 用 `nextInitializedTickWithinOneWord` 在一个 256-bit 的 word 里找下一档，找不到就停在 word 边界，循环再进来。

### 18. 为什么 fee 要绑 tickSpacing？

工厂里档位和间距绑在一起。本仓库构造函数写死：

| fee | 交易者费率 | tickSpacing |
| --- | --- | --- |
| 500 | 0.05% | 10 |
| 3000 | 0.30% | 60 |
| 10000 | 1% | 200 |

`enableFeeAmount` 还能开别的档，`tickSpacing` 限制在 `(0, 16384)`，避免 bitmap 的索引在合法 tick 上溢出。主网后来另开了 `100 / 1`（0.01%）。

间距是 LP 能挂单的价格网格。费率越低，做市越要贴着现价，网格越密。费率高的池子允许更疏的网格，swap 跨 tick 的次数更少。

头寸边界和 bitmap 索引都要能被 `tickSpacing` 整除。同一对 token、不同 fee，是不同的池子，CREATE2 的 salt 把 fee 算进去了。

### 19. swap 的数量符号，站在谁的视角？

`swap(recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data)`：

- `amountSpecified > 0`：exact input
- `amountSpecified < 0`：exact output
- `0`：直接 `AS`

返回值 `(amount0, amount1)` 是池子视角。正数是池子收入。Router 把负的那一侧取反，当成用户收到的数量。

`zeroForOne` 为真：用户付 token0，池子付 token1，价格下降。

`sqrtPriceLimitX96` 是这一笔允许走到的价格尽头，必须落在现价和 `MIN/MAX_SQRT_RATIO` 之间，而且不能等于端点。它不代替 `amountOutMinimum`。价格碰到 limit 可以只成交一部分；最少收到多少，由 Router 在 swap 返回后检查。

### 20. 为什么改成回调里付款？

V2 的 Pair 得等 token 已经躺在自己余额里，才能知道输入是多少。V3 的输入量要走完 tick 才算得出来，所以顺序倒过来：池子先把输出转给 `recipient`，再 `uniswapV3SwapCallback`，调用方在回调里把输入转进池子，池子再查 `balance` 增加了没有（`IIA`）。

多付可以通过。少付回滚。

`CallbackValidation` 不信任调用方自己说池子地址。它用 factory、token、fee 重新 CREATE2 算出池地址，要求 `msg.sender` 等于这个地址。

`swap` 不用 `lock` 这个 modifier。它自己把 `unlocked` 设为 false，末尾设回 true。回调发生时锁是关的，回调里再 `mint` / `swap` / `flash` 会失败。若先用 modifier 把锁翻转再读 `slot0`，读出来的 `unlocked` 已经是 false，`LOK` 会一直触发。

### 21. exact output 的多跳为什么长在回调里，exact input 不用？

exact input 知道每一跳付多少。Router 自己循环：中间跳的接收者写成 Router，最后一跳才给用户。下一跳的 `payer` 改成 Router 自己。

exact output 知道的是最终要收到多少，不知道用户该付多少。path 从输出 token 往输入 token 编码。外层池子在回调里说「我还要多少输入」，Router 把这个数量当成下一跳的精确输出，再 swap 一次。最内层才 `pay` 用户。用户真正付的数量写进 `amountInCached`，因为最外层 `swap` 的返回值不是这个数。

### 22. 头寸存在 core，NFT 在 periphery。谁有权 `burn`？

core 的 key 是：

```text
keccak256(abi.encodePacked(owner, tickLower, tickUpper))
```

`mint` 的 `recipient` 被写成 owner。`burn` 和 `collect` 用 `msg.sender` 当 owner。

NonfungiblePositionManager 铸流动性时 recipient 固定是它自己。用户拿到的是 ERC721。之后 burn、collect 都由这个管理器去调池子。Router 不加流动性，它不持有头寸。

撤干净的顺序：`burn(liquidity)` 把 token 记进 `tokensOwed`，`collect` 转走，流动性与欠款都是 0 之后，periphery 再烧 NFT。core 没有 NFT。

### 23. 协议费在 V3 里从谁的口袋出？

从 LP 的手续费里切，不额外向交易者加价。

`feeProtocol` 是分母，每种 token 占 4 bit，合法值是 `0` 或 `4..10`。一步 swap 里：

```text
protocolFee = feeAmount / feeProtocol
```

其余进 `feeGrowthGlobal`。`feeProtocol = 6` 时，协议拿走这笔手续费的 1/6，和 V2 的比例一样，但是当时就记进 `protocolFees`，由工厂 owner `collectProtocol`，不再等到 `mint` 时铸份额。

交易者面对的仍是池子不可变的 `fee`。打开协议费，LP 变少拿，成交价不变。

### 24. 预言机记的是 tick，不是价格

`observations` 里是 `tickCumulative` 和 `secondsPerLiquidityCumulativeX128`。时间加权的是 tick。阅读方用两个观察的 tick 累计差除以时间，得到平均 tick，再换回价格。

现价内的流动性变化也要写。`mint` / `burn` 改到价格内的 `liquidity` 时，先 `observations.write`，否则 `secondsPerLiquidity` 的分母是错的。

cardinality 要事先 `increaseObservationCardinalityNext` 扩容。没扩容的池子只有很短的历史。同一区块重复写，直接返回，不新开一条。

### 25. `flash` 和 swap 回调差在哪？

`flash` 把 `amount0`、`amount1` 直接借出，回调里按池子的 `fee` 还本金加手续费。它不走价格，也不要求 K 形变。检查的仍是回调前后的余额。

手续费进 `feeGrowthGlobal` 和协议费，所以这笔钱会分给当时价格内的 LP。借出期间锁是关的。

### 26. 集中流动性把无常损失变成什么样？

窄区间是加杠杆的全区间头寸。现价还在区间里时，同样的价格移动会让两边数量变化得更快；价格走出区间，头寸变成 100% 单边，之后的反向波动不再被你的库存吸收，直到价格走回来。

全区间、间距足够密的 V3 头寸，行为接近 V2。资本效率更高的那一段，库存风险也更集中。

刚好卡在区间边缘挂上、吃完这笔手续费立刻撤走，是 JIT。协议不禁止。防御在交易者的滑点，或者在一个会拒绝「同一区块内刚加上的流动性」的执行环境里。V4 把这种规则放到 hook 里。

---

## V4

### 27. 为什么收成一个 `PoolManager`？

V2/V3 每个池子是一个合约。多跳要在池子之间做 ERC20 转账，建池要部署合约。

V4 所有池的状态都在 `PoolManager` 的存储里。建池是 `initialize`，写一条状态，不部署池合约。一次 `unlock` 里可以 swap 多次、改多次流动性，中间不转账，结束时按净额结算。

池子用 `PoolKey` 标识：

```text
currency0, currency1, fee, tickSpacing, hooks
PoolId = keccak256(abi.encode(poolKey))
```

`currency0 < currency1`。原生 ETH 是 `address(0)`，所以只要有 ETH，它就是 `currency0`。

`tickSpacing` 不再由工厂按费率配表。每个池在 key 里自己带。`TickMath` 里 `MIN_TICK_SPACING = 1`，`MAX_TICK_SPACING = type(int16).max`，也就是 32767。费率和网格解耦。

hook 写在 key 里，`initialize` 时定死，之后不能换。换 hook 就是另一个池子。

### 28. flash accounting 的 delta 符号怎么读？

`unlock` 的调用方实现 `unlockCallback`。回调里才能 `swap`、`modifyLiquidity`、`donate`、`take`、`settle`、`mint`、`burn`、`sync`。`initialize` 不改余额，不必先 `unlock`。

每种货币一个 delta，放在 transient storage（EIP-1153）里：

- 负数：调用方欠 `PoolManager`，要 `settle`
- 正数：`PoolManager` 欠调用方，可以 `take`，或者 `mint` 成 ERC-6909 债权

`unlock` 返回前，这个调用方的全部 delta 必须是 0。transient storage 会在交易结束时被 EVM 清掉，所以偿付必须由 `unlock` 末尾的检查来保证，不能指望「交易结束自然清零」。

一次多跳只在最后按净额转一次。例如先把 5 USDC 换成 5 USDT，再用 15 USDC + 25 USDT 加流动性，中间那 5 个只留在 delta 里。

### 29. V4 的 exact input 为什么是负数？

和 delta 的符号一致：负数表示调用方付出。

`SwapParams.amountSpecified < 0` 是 exact input：你指定自己要付多少。`> 0` 是 exact output：你指定自己要收多少。`PoolManager.swap` 里 `amountSpecified == 0` 直接回滚。

返回的 `BalanceDelta` 也是调用方视角。普通的 exact-input、`zeroForOne`：`amount0` 为负，`amount1` 为正。

V3 的 `amountSpecified > 0` 才是 exact input，返回值是池子视角，正数表示池子收入。两边的符号表要分开背。

### 30. hook 的权限为什么写在地址里？

`PoolManager` 不必先读 hook 的存储，看地址最低 14 位就知道要不要调用。`Hooks.ALL_HOOK_MASK = (1 << 14) - 1`。从低位往高位：

| bit | 标志 |
| --- | --- |
| 0 | `AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA` |
| 1 | `AFTER_ADD_LIQUIDITY_RETURNS_DELTA` |
| 2 | `AFTER_SWAP_RETURNS_DELTA` |
| 3 | `BEFORE_SWAP_RETURNS_DELTA` |
| 4 | `AFTER_DONATE` |
| 5 | `BEFORE_DONATE` |
| 6 | `AFTER_SWAP` |
| 7 | `BEFORE_SWAP` |
| 8 | `AFTER_REMOVE_LIQUIDITY` |
| 9 | `BEFORE_REMOVE_LIQUIDITY` |
| 10 | `AFTER_ADD_LIQUIDITY` |
| 11 | `BEFORE_ADD_LIQUIDITY` |
| 12 | `AFTER_INITIALIZE` |
| 13 | `BEFORE_INITIALIZE` |

源码里的例子：`0x...2400` 的低位是 `10 0100 0000 0000`，也就是 bit 13 和 bit 10，`beforeInitialize` 与 `afterAddLiquidity`。

部署时用 CREATE2 把 salt 挖到这些位上。构造函数里 `validateHookPermissions`，声明的权限和地址不一致就 revert。

`isValidHookAddress` 再加三条：

- 返回 delta 的位，必须同时有对应的动作位。有 `BEFORE_SWAP_RETURNS_DELTA` 就必须有 `BEFORE_SWAP`。
- `hooks == address(0)` 时，fee 不能是动态费。
- hook 不是 0 时，要么至少有一个标志位，要么这是动态费池。

hook 必须把调用它的函数选择子原样返回，否则 `InvalidHookResponse`。

### 31. 动态手续费的两个入口

`LPFeeLibrary.DYNAMIC_FEE_FLAG = 0x800000`。它大于静态费上限 `MAX_LP_FEE = 1_000_000`（100%），所以不会和某一档静态费撞号。

动态费池的初始 LP 费是 0。hook 若要非 0 的初始费，在 `afterInitialize` 里调 `updateDynamicLPFee`。这个函数只接受 `msg.sender == hook`。

另一条路是 `beforeSwap` 的返回值。带 `OVERRIDE_FEE_FLAG = 0x400000` 时，这一笔用返回的费率，不改池子里存的费率。只有动态费池能这么做。返回值的长度必须是 96 字节：选择子、delta、费率。

静态费池的 `fee` 在 `PoolKey` 里，初始化后不变。

### 32. 协议费和 LP 费的顺序

V4 先扣协议费，再对剩下的输入扣 LP 费。单方向的合成费率是：

```text
swapFee = protocolFee + lpFee - protocolFee * lpFee / 1_000_000
```

协议费每种方向最多 `1000`（0.1%），两种方向各 12 bit，打在一个 `uint24` 里。上限写在 `ProtocolFeeLibrary.MAX_PROTOCOL_FEE`，再大，`Pool.swap` 的中间乘积会溢出。

谁能改，由 `protocolFeeController` 决定，不是 LP，也不是 hook 随便写。

三版的口袋不一样。V2、V3 的交易者费率不因协议费而提高，协议费从 LP 的手续费里切。V4 的协议费加在交易者身上，LP 费只作用于扣完协议费的剩余输入。

### 33. hook 怎样改一笔 swap，又不能把 exact in 改成 exact out？

`beforeSwap` 在有 `BEFORE_SWAP_RETURNS_DELTA` 时，可以返回 specified delta，从 `amountSpecified` 里加掉一截。核心只用剩下的 `amountToSwap` 走集中流动性。

若这笔原本是 exact input（负数），hook 改完变成正数，`HookDeltaExceedsSwapAmount`。反过来也一样。hook 可以把自己负责的那一段拿满，让核心成交量变成 0，但不能把方向反转。

`afterSwap` 再处理 unspecified 那一条腿：hook 实际交出或拿走的另一种货币。hook 的 delta 记在 hook 地址上，调用方的 delta 减去这一份。没有对应的 returns-delta 标志时，返回的 delta 被当成 0。

这就是自定义曲线的边界。核心仍是集中流动性。hook 把成交量从核心拿走，自己记账，`PoolManager` 只做结算层。白皮书里的例子包括提取费、包装资产，以及在 hook 里做一条 V2 那样的恒定乘积。

`noSelfCall`：动作出自 hook 自己时，不再调用这个 hook。否则 hook 在回调里再 swap，会套住自己。能再调用 `swap` 的前提仍是「你就是当前的 locker」。Router 是 locker 时，hook 不能绕过它再开一笔。

### 34. `salt` 解决了 V3 的哪个限制？

V3 同一个 owner、同一对 tick，只有一条头寸。V4 的 key 多一个 `bytes32 salt`：

```text
positionKey = keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))
```

`PositionManager` 是 core 里的 owner，salt 用 NFT 的 tokenId 补成 32 字节。同一个管理器才能在同一区间给不同用户各开一条。

fee growth 的算法仍是 V3 那套：`feeGrowthInside` 的差乘 `liquidity` 再除 `2^128`。`liquidity == 0` 时不允许 poke。

### 35. `donate` 是什么？

把 token0 / token1 直接加进当前价格内 LP 的 fee growth，不改价格，也不改流动性。价格内 `liquidity == 0` 时没有接收者，调用失败。

hook 用它给在范围内的 LP 发奖励。权限位是 `beforeDonate` / `afterDonate`。它同样发生在 `unlock` 里，捐赠者的 delta 变负，结束前要 settle。

### 36. 原生 ETH 和 ERC-6909 各省了哪一次转账？

原生 ETH 不再先 `WETH.deposit`。`settle` 可以附带 `msg.value`，`take` 直接把 ETH 转出。

ERC-6909 是 `PoolManager` 内部的多代币债权，id 是货币地址。`mint` 把你名下的正 delta 收成债权，token 仍停在 `PoolManager` 的余额里。下次使用再 `burn` 变回 delta。频繁交易或 hook 要跨交易持有库存时，省掉每次进出的 ERC20 转账。

`sync` 给转账扣费的代币用。先记下 `PoolManager` 当前余额，再把代币转进来，`settle` 按实际增加的余额入账。V3 的检查是「余额至少增加应付数量」，转账扣费会少到，回调直接失败。

### 37. 核心为什么删掉预言机？

V3 每个池都带 `observations`。改价格内流动性、跨 tick 的 swap，都要为可能没人读的 TWAP 写存储。

V4 核心不写这条。需要预言机的池子，在 `afterSwap` 或流动性 hook 里自己记。大多数池子不为它付 gas。阅读状态走 `extsload` / `exttload`：`PoolManager` 暴露存储槽读取，`StateView` 在外围解析，避免把每个 getter 都编进单例合约。

### 38. 恶意 hook 能做什么，交易者靠什么约束它？

hook 是池子的一部分。谁和这个 `PoolKey` 交易，谁就在执行这段外部代码。它可以对调用者加价、拒绝成交、在 returns-delta 的权限内改两条腿的数量。

`PoolManager` 保证的是：标志位和调用一致、选择子被原样返回、exact in/out 不被翻转、`unlock` 结束时 delta 结清、没有标志位的 hook 拿不到 delta。它不保证 hook 的定价对用户公平。

用户侧的约束在外围：`amountOutMinimum`、价格限制、以及只跟已知 hook 的池子成交。`noDelegateCall` 仍在，防止把 `PoolManager` 的逻辑放到别的存储上执行。

---

## 三版放在一起问

### 39. 一笔 exact input 单跳，钱按什么顺序动？

V2：用户在调用前把输入转进 Pair。Pair 把输出转给接收者。`data` 为空则不回调。最后用余额反推输入，做 K 检查，`_update` 储备。

V3：用户调用 Router。池子先把输出转走，再回调 Router。Router 从用户 `transferFrom` 输入。池子检查自己的余额增加了不少于它算出的输入。

V4：Router `unlock`。`swap` 只把负的输入和正的输出记到 delta。回调返回前 Router `settle` 输入、`take` 输出。中间没有 ERC20 转账。

### 40. 手续费最后进了谁的余额？

V2：留在 Pair 的 token 余额里，储备在 `_update` 时跟上。LP 没有单独的费。协议费是稍后铸出来的 LP，不是单独一笔 token。

V3：先记在 `feeGrowthGlobal`，再结算进头寸的 `tokensOwed`，`collect` 才变成转账。协议费进 `protocolFees`，工厂 owner 领。价格外的头寸这一段 inside 不变，领到 0。

V4：LP 费仍走 fee growth。协议费在输入上先扣，上限 0.1% 每方向，记在管理器里由协议领取。hook 若有 returns-delta，还可以在这两笔之外从调用方的 delta 里再拿。

### 41. 同一笔流动性，三版的所有权凭证是什么？

V2：Pair 的 ERC20。谁持有 LP，谁按比例拥有储备。转账就是转头寸。

V3：core 账本认 `recipient`。用户通常持有 NonfungiblePositionManager 的 NFT。把 NFT 转走，就是把外围的控制权转走；core 里的 owner 仍是管理器。

V4：core 认 `owner + salt`。经 `PositionManager` 开的仓，owner 是管理器，salt 是 tokenId。直接跟 `PoolManager` 交互的合约，可以自己当 owner，自己选 salt。

### 42. 闪电贷三版怎么做？

V2：`swap` 时 `data` 非空，乐观转出，回调里还上带 0.3% 费的 K。可以两腿一起借。

V3：专门的 `flash`。还本金，再按池子 `fee` 付费。费分给当前价格内的 LP。不改价格。

V4：不必单独的 flash 入口。`unlock` 里先 `take`，任意使用，回调结束前 `settle` 回来，净 delta 为 0 即可。只借只还、没有 swap 时，核心不另加一档手续费。想收费就在 hook 或外围做。

### 43. 为什么 V3 要先 `initialize`，V2 的首笔 `mint` 就够了？

V2 的价格就是储备比。首笔 `mint` 把两边数量放进去，价格一起诞生。

V3 的价格是独立状态。`initialize(sqrtPriceX96)` 写下价格和第一颗 oracle，并把 `unlocked` 设为 true。这时 `liquidity` 仍是 0。价格可以由第一个调用者设成任意合法值。LP 要自己核对现价再 `mint`。

V4 一样：`initialize` 写 `sqrtPriceX96`，并可调用 `beforeInitialize` / `afterInitialize`。动态费池在这一步之后才有机会把费率从 0 改掉。

### 44. 多跳为什么 V4 更省？

V2/V3 每一跳的输出都要变成下一跳池子里的真实 token 余额。路径上每个池是不同合约，中间代币至少转一次。

V4 路径上的池子共享一个余额账。`unlock` 里连续 `swap`，delta 按货币轧差。只对最终净额做转账。hook 若在中间回调外部合约，这笔 gas 会回来；省掉的是池子与池子之间被迫的 token 转账，不是 hook 自己的逻辑。

### 45. 从 V3 迁到 V4，哪些概念可以原样用？

可以直接用的：tick、`sqrtPriceX96`、`L` 与两边数量的换算、`liquidityNet` / `liquidityGross`、fee growth 的 inside / outside / last、价格内才赚手续费、exact in 与 exact out 的滑点检查放在外围。

必须改口的：

- 池地址换成 `PoolId`
- exact input 的符号从正变成负
- 付款从「回调里转进池子」换成「delta 轧差后 settle」
- 费率可以不是 key 里的那个静态数
- 预言机不再默认附带
- 同一个区间可以有多条头寸，因为有 `salt`
- 对手方多了一个 hook，滑点检查要覆盖 hook 改出来的数量

### 46. 面试官让你设计下一代 AMM，从哪一版往下讲？

先复述已经存在的拆分，再改一个维度。

V2 把不变量收成 `k`，用余额差当输入。V3 把流动性收成区间，把付款改成回调，因为输入要等 tick 走完才知道。V4 把池子收成单例，把转账收成交易末尾的净额，把可变行为收成地址里编码的 hook。

每说一个改进，就带上它的代价：

- 单例省掉跨池转账，也把所有池的升级和暂停绑在同一个合约上。`PoolManager` 的逻辑应当固定，变化放在 hook。
- hook 让池子能做动态费、限制 JIT、自定义曲线，也让「这个池子安全」变成「这段外部代码安全」。
- 核心删掉预言机，是默认不为没人读的存储付费。需要 TWAP 的借贷协议得自己确认 hook 的算法和权限位。
