# Uniswap V3 代码阅读路线

对着本地 `uniswapv3/v3-core` 和 `uniswapv3/v3-periphery` 读。本仓库 `src/uniswapv2/` 是 V2，和这份无关。默认你已经知道集中流动性、tick、`sqrtPriceX96`。fee growth 写在存储一节后面。下面只标**先打开哪个文件、顺着哪次调用往下走、代码里哪一行决策容易看漏**。

Solidity `0.7.6`。core 主许可是 BUSL-1.1，periphery 是 GPL-2.0-or-later。接口可以当目录用：`IUniswapV3Pool` 由六块小接口拼成，动作签名以 `v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol` 为准。

两遍。第一遍只跟四条调用链（建池、mint、swap、burn/collect），数学库在被调用的那一行打开，看完回到调用方。第二遍再拆 oracle、flash、Quoter、NFT 图片。

---

## 先看哪、先跳过哪

| 先读 | 作用 |
| --- | --- |
| `v3-core/contracts/UniswapV3Factory.sol` | 谁有权建池、fee 和 tickSpacing 怎么绑 |
| `v3-core/contracts/UniswapV3PoolDeployer.sol` | CREATE2 + 瞬时 `parameters` |
| `v3-core/contracts/UniswapV3Pool.sol` | 全部状态变更都在这一个合约 |
| `v3-core/contracts/libraries/Tick.sol` | tick 两侧的流动性与 fee outside |
| `v3-core/contracts/libraries/TickBitmap.sol` | swap 下一步跳到哪个已初始化 tick |
| `v3-core/contracts/libraries/Position.sol` | 单个 LP 头寸的流动性与待领手续费 |
| `v3-core/contracts/libraries/SwapMath.sol` | 一个价格区间内的一步 swap |
| `v3-core/contracts/libraries/SqrtPriceMath.sol` | 价格与 token 数量，含舍入方向 |
| `v3-periphery/contracts/SwapRouter.sol` | exact in / exact out、单跳与多跳 |
| `v3-periphery/contracts/base/LiquidityManagement.sol` | token 数量换成 liquidity，再 `pool.mint` |
| `v3-periphery/contracts/NonfungiblePositionManager.sol` | ERC721 包一层，和 core position 是两套账 |
| `v3-periphery/contracts/libraries/CallbackValidation.sol` | 回调里确认 `msg.sender` 是算出来的池子 |
| `v3-periphery/contracts/libraries/PoolAddress.sol` | 与 factory 同一套 CREATE2 地址公式 |
| `v3-periphery/contracts/libraries/Path.sol` | `token + fee + token + fee + token` 的紧凑编码 |

先跳过：`contracts/test/`、`audits/`、`NFTDescriptor.sol`、`NFTSVG.sol`、`HexStrings.sol`、`TokenRatioSortOrder.sol`。`LowGasSafeMath`、`SafeCast`、`BitMath`、`UnsafeMath` 遇到调用再看，它们是 gas 版算术，没有协议状态。

最小可运行回调在 `v3-core/contracts/test/TestUniswapV3Callee.sol`。卡住某一条公式时，对同名的 `*Test.sol`，Echidna 放后面。

---

## 阅读顺序

### 1. 池子地址为什么不含构造参数

读 `UniswapV3Factory.createPool` → `UniswapV3PoolDeployer.deploy` → `UniswapV3Pool` 构造函数。

`createPool` 把两个 token 按地址排序成 `token0 < token1`，用 `feeAmountTickSpacing[fee]` 取出间距，然后 `deploy`。构造函数里写死的只有三档：`500 → 10`、`3000 → 60`、`10000 → 200`。别的档位走 `enableFeeAmount`，`tickSpacing` 限制在 `(0, 16384)`，注释写的是防止 bitmap 在合法 tick 上溢出 `int24`。

`deploy` 先把参数写进自己的 `parameters`，再：

```35:36:uniswapv3/v3-core/contracts/UniswapV3PoolDeployer.sol
        pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
```

池子构造函数从 `msg.sender.parameters()` 读出 factory、token、fee、tickSpacing，收成 `immutable`。`delete parameters` 让这个存储槽只在部署那一瞬间有值。

periphery 的 `PoolAddress.computeAddress` 用同一 salt `keccak256(abi.encode(token0, token1, fee))`，再拼上写死的 `POOL_INIT_CODE_HASH`。池子没有构造参数，init code 才是常量，periphery 才能不读 factory 存储、直接算出池地址。`CallbackValidation.verifyCallback` 就是 `msg.sender == computeAddress(...)`。

`getPool` 正反两个方向都写了同一地址。salt 只用排序后的那一对。

`NoDelegateCall` 把部署时的 `address(this)` 存进 immutable。`createPool`、池子的 `swap` / `flash`，以及经 `_modifyPosition` 走到的 mint/burn，都挂了这个检查。比较放在私有函数 `checkNotDelegateCall` 里，避免 modifier 内联时把 20 字节地址复制进每个函数体。

### 2. 池子状态：先看存储，再看谁能改它

打开 `UniswapV3Pool.sol` 前 160 行，加上 `libraries/Tick.sol` 的 `Info`、`libraries/Position.sol` 的 `Info`。

`Slot0` 占一个 slot：`sqrtPriceX96`、`tick`、oracle 的 index / cardinality / cardinalityNext、`feeProtocol`、`unlocked`。`feeProtocol` 是一个 `uint8`：低 4 bit 是 token0 的分母，高 4 bit 是 token1。`setFeeProtocol` 只允许 `0` 或 `4..10`。

旁边还有：`feeGrowthGlobal{0,1}X128`、`protocolFees`、当前价格内的 `liquidity`、`ticks`、`tickBitmap`、`positions`、`observations[65535]`。

头寸 key 两边是同一个公式，periphery 抽到 `PositionKey.compute`：

```36:36:uniswapv3/v3-core/contracts/libraries/Position.sol
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
```

`owner` 是调用 `mint` 时传入的 recipient。`burn` / `collect` 用 `msg.sender` 当 owner。谁被写成 recipient，谁才能 burn。Router 不持有流动性。NonfungiblePositionManager mint 时 recipient 固定是 `address(this)`，用户拿到的是 NFT。

`lock` 把 `slot0.unlocked` 拉低。`initialize` 之前 `unlocked` 是 false，`mint` / `flash` / `collect` / `burn` 都进不去。`initialize` 不加 `lock`：它自己把 `unlocked` 设成 true，重复调用用 `sqrtPriceX96 == 0` 挡（`AI`）。

`swap` 不用 `lock` 这个 modifier。它先把整个 `slot0` 抄进内存并 `require(unlocked)`，再自己把 `unlocked` 设为 false，函数末尾设回 true。modifier 会先翻转锁，抄出来的 `unlocked` 已经是 false，`LOK` 会一直触发。回调发生时锁是关的，回调里再进 `mint` / `swap` / `flash` 会失败。支付校验靠回调前后的 `balanceOf`，所以这把锁盖住整个合约。

### fee growth

fee growth 是池子上一直往上加的计数器：从初始化到现在，**每一单位正处在价格区间内的流动性，累计分到了多少手续费**。存进去的数乘了 `2^128`，所以变量名带 `X128`，整数除法也能留下小数。`FixedPoint128.Q128` 就是这个 `2^128`。

token0、token1 各有一个全局值：`feeGrowthGlobal0X128`、`feeGrowthGlobal1X128`。swap 走完一步、协议费切走之后，只改输入 token 的那一个：

```688:690:uniswapv3/v3-core/contracts/UniswapV3Pool.sol
            if (state.liquidity > 0)
                state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);
```

也就是 `feeGrowthGlobal += feeAmount * 2^128 / liquidity`。除数是这一步价格内的流动性。`liquidity == 0` 的区间可以走过去，这一步不加，因为没有人在里面。

每笔 swap 不更新各个头寸。头寸只存上次结算时看到的区间内累计值 `feeGrowthInside{0,1}LastX128`。下次 `mint`、`burn`，或者 `burn(0)` 这种 poke，才结算：

```text
tokensOwed = (现在的 feeGrowthInside - 上次记下的 feeGrowthInside) × 该头寸的 liquidity / 2^128
```

用的是结算前的 liquidity。两次快照的差，就是这段时间新赚的手续费，先记在 `tokensOwed` 里，`collect` 才转走。

`feeGrowthInside` 不是全局那个数。只有价格落在 `[tickLower, tickUpper)` 里时产生的手续费才算这个头寸的。上下两个 tick 上各存一份 `feeGrowthOutside`，表示这条边界另一侧的累计。`Tick.getFeeGrowthInside` 做：

```text
inside = global − below − above
```

价格在边界的哪一侧，决定 below/above 直接用 `feeGrowthOutside`，还是用 `global - feeGrowthOutside`。穿过 tick 时 `Tick.cross` 把 outside 换成 `global - outside`，穿过之后“另一侧”仍然成立。这些 outside 只有相对意义：tick 第一次被初始化时才赋值，而且只有 `tick <= tickCurrent` 才把当时的全局值抄进去。约定是初始化之前的增长都算在 tick 下面。

三处存储各管一件事：

| 存在哪 | 字段 | 含义 |
| --- | --- | --- |
| 池子 | `feeGrowthGlobal{0,1}X128` | 全池、每单位在价格内流动性的累计手续费 |
| 每个已初始化 tick | `feeGrowthOutside{0,1}X128` | 这条边界另一侧的累计，用来切出区间内的部分 |
| 每个头寸 | `feeGrowthInside{0,1}LastX128` | 该头寸上次结算时的区间内累计 |

数值上：价格内流动性是 `1000`，这一步分给 LP 的 token0 手续费是 `100`，则 `feeGrowthGlobal0X128` 增加 `100 * 2^128 / 1000`。一个流动性为 `100`、整段时间都在区间内的头寸，结算得到 `10` 个 token0。同一区间里流动性为 `900` 的其余头寸分走剩下的 `90`。区间外的头寸，inside 在这段时间不变，结算得到 `0`。

Solidity 0.7 的 `uint256` 减法在溢出时回绕。全局值大到绕回 `0` 之后，`现在 - 上次` 仍然是这段增量。绝对大小没有意义，头寸只使用两次快照的差。

### 3. 建池之后的第一笔：`initialize`

`initialize(sqrtPriceX96)`：

1. `TickMath.getTickAtSqrtRatio` 得到当前 tick。价格区间是 `[MIN_SQRT_RATIO, MAX_SQRT_RATIO)`，右端开区间。
2. `Oracle.initialize` 在 `observations[0]` 写第一条，cardinality 从 1 开始。
3. 写入 `Slot0`，`feeProtocol = 0`，`unlocked = true`。

此时 `liquidity == 0`，bitmap 为空。价格有了，可交易流动性还没有。

`TickMath.getSqrtRatioAtTick` 不用推导。看两件事：常数表按 tick 的二进制位乘 `1.0001^(2^k)` 的 Q128.128；最后收到 Q64.96 时向上取整，注释要求 `getTickAtSqrtRatio(getSqrtRatioAtTick(tick))` 对得上。

### 4. 加流动性：`mint` → `_modifyPosition` → `_updatePosition`

外部入口是 `mint(recipient, tickLower, tickUpper, amount, data)`。`amount` 已经是 liquidity。token 数量由池子算完，在回调里向 `msg.sender` 要。

```text
mint
  _modifyPosition
    _updatePosition
      ticks.update(lower, upper=false)
      ticks.update(upper, upper=true)
      tickBitmap.flipTick          // 仅当 liquidityGross 在 0 与非 0 之间翻转
      ticks.getFeeGrowthInside
      position.update              // 区间内新增的 fee growth 记进 tokensOwed
    SqrtPriceMath.getAmount{0,1}Delta
  uniswapV3MintCallback
  balance 检查（M0 / M1）
```

`_modifyPosition` 用当前 tick 分三支，这是金额计算的分叉：

| 当前 tick | 用户要付 | 价格内的 `liquidity` |
| --- | --- | --- |
| `< tickLower` | 只付 token0 | 不动 |
| `[tickLower, tickUpper)` | token0 用现价到上界，token1 用下界到现价 | `LiquidityMath.addDelta` |
| `>= tickUpper` | 只付 token1 | 不动 |

现价落在区间内时，改 `liquidity` 之前先 `observations.write`。价格没动、价格内流动性变了，oracle 仍要记一笔，否则 `secondsPerLiquidity` 的分母是错的。

`Tick.update` 里钉住：

- `liquidityGross` 是引用这个 tick 的流动性绝对值之和，用来判断 tick 是否还存在，并受 `maxLiquidityPerTick` 限制（`LO`）。
- `liquidityNet`：下界 `+= delta`，上界 `-= delta`。从左向右穿过时，把 `liquidityNet` 加进当前流动性，就是进入下界、离开上界。
- tick 第一次初始化时，只有 `tick <= tickCurrent` 才把全局 fee growth / tickCumulative 抄进 `*Outside`。约定是初始化之前的增长都算在 tick 下面。`*Outside` 只有相对意义。
- `flipped` 为真才 `flipTick`。bitmap 的索引是 `tick / tickSpacing`。`flipTick` 要求 `tick % tickSpacing == 0`。

`position.update` 的手续费用更新前的 liquidity：

```60:67:uniswapv3/v3-core/contracts/libraries/Position.sol
        uint128 tokensOwed0 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );
```

`liquidityDelta == 0` 是一次 poke：不改流动性，只把 fee 结算进 `tokensOwed`。liquidity 已经是 0 时再 poke，直接 `NP`。

回调之后池子不 `transferFrom`。它要求 `balanceBefore + amount <= balanceAfter`，多付可以通过。token 要在回调里转到池子地址。

接着读 `LiquidityManagement.addLiquidity`：先 `pool.slot0`，再用 `LiquidityAmounts.getLiquidityForAmounts` 把 `amount0Desired` / `amount1Desired` 收成一个 liquidity（取两侧里更紧的那个），然后 `pool.mint`。滑点检查在 mint 返回之后：`amount0 >= amount0Min && amount1 >= amount1Min`。

### 5. 减流动性和领手续费

`burn(tickLower, tickUpper, amount)` 仍走 `_modifyPosition`，`liquidityDelta` 为负。算出来的 token 数量在返回值里是负数，函数取反后加进 `position.tokensOwed{0,1}`。这一步不转账。

`liquidityDelta < 0` 且 tick 翻回未初始化时，`ticks.clear` 删掉整个 tick。顺序是先 `position.update`（还要用 outside 算 fee），再 clear。

`collect` 只减 `tokensOwed` 并 `safeTransfer`。它不调用 `getFeeGrowthInside`。区间里已经产生、还没 poke 进 `tokensOwed` 的手续费，collect 看不到。

NonfungiblePositionManager 的 `collect` 因此在 `pool.collect` 之前，如果头寸还有流动性，会先 `pool.burn(..., 0)`。那次 burn 只做 poke。

撤出顺序：`burn(liquidity)` → `collect` →（流动性与 tokensOwed 都为 0 之后）periphery 的 `burn(tokenId)` 才烧 NFT。core 没有 NFT。

### 6. Swap：只精读 `swap` 的 while

入口：`swap(recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data)`。

- `amountSpecified > 0` 是 exact input，`< 0` 是 exact output，`0` 直接 `AS`。
- `zeroForOne` 为真时价格下降，池子付出 token1，回调里要 token0。
- `sqrtPriceLimitX96` 必须落在当前价格和 `MIN/MAX_SQRT_RATIO` 之间，且不能等于端点（`SPL`）。Router 在用户没传 limit 时用 `MIN_SQRT_RATIO + 1` 或 `MAX_SQRT_RATIO - 1`。

循环条件：指定量还没用完，且价格还没顶到 limit。一步之内：

```646:671:uniswapv3/v3-core/contracts/UniswapV3Pool.sol
            (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                tickSpacing,
                zeroForOne
            );
            // ... 夹到 MIN_TICK / MAX_TICK ...
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                fee
            );
```

`nextInitializedTickWithinOneWord` 只在一个 bitmap word（压缩后 256 个 tick）里找。没找到就返回这个 word 的边界，`initialized = false`。跨 word 靠循环再进来。压缩时对负 tick 向负无穷取整：`tick < 0 && tick % tickSpacing != 0` 时 `compressed--`。Solidity 除法向 0 截断，这一行是补丁。

`SwapMath.computeSwapStep` 按 `exactIn` 和 `zeroForOne` 四象限调用 `SqrtPriceMath`。盯两处：

- exact input 先扣 fee，用 `amountRemaining * (1e6 - feePips) / 1e6` 推下一步价格。这一步没撞到目标价时，`feeAmount = amountRemaining - amountIn`，余数全部当手续费。撞到目标价才用 `mulDivRoundingUp(amountIn, feePips, 1e6 - feePips)`。
- token0 的下一步价格向上取整，token1 向下取整。注释在 `getNextSqrtPriceFromAmount0RoundingUp` / `Amount1RoundingDown`：exact output 时价格至少走到够付出的位置，exact input 时不要走过头。

回到循环后段：

- 手续费进 `feeGrowthGlobalX128` 时除以这一步的 `state.liquidity`。`liquidity == 0` 的区间可以走过，但不累加 fee growth。
- `feeProtocol` 是分母：`delta = feeAmount / feeProtocol` 进协议，剩下的给 LP。
- 价格走到 `sqrtPriceNextX96` 且该 tick 已初始化，才 `ticks.cross`。cross 把每个 `*Outside` 换成 `global - outside`，返回 `liquidityNet`。`zeroForOne` 时把 `liquidityNet` 取负，因为 net 的符号定义是从左往右。
- 穿过之后，`zeroForOne` 把 `state.tick` 设成 `tickNext - 1`，反方向设成 `tickNext`。tick 是价格所在区间的下边界。往左穿过 `tickNext` 时，价格落在该档左侧。
- 没穿过、价格动了，用 `getTickAtSqrtRatio` 重算 tick。
- `observeSingle(..., secondsAgo=0)` 懒计算：这一笔里第一次 cross 才算。`observations.write` 用起始 tick 和起始 liquidity，并且只在最终 tick 与起始 tick 不同时写。同一区块重复 write，`Oracle.write` 直接返回。

结算：先把给用户的 token 转出去（amount 为负的一侧），再回调要钱，再检查池子余额增加了应付的数量（`IIA`）。

`swap` 返回的 `(amount0, amount1)` 是池子视角：正数是池子收入。Router 取输出时对负的那一侧取反。

### 7. 手续费在 tick 两侧怎么拼回去

概念在上面的 [fee growth](#fee-growth)。这里对着 `Tick.getFeeGrowthInside` 和 `Tick.cross` 把分支走一遍。

inside = global − below − above。当前 tick 在边界的哪一侧，决定直接用 `feeGrowthOutside`，还是用 `global - feeGrowthOutside`。cross 的减法让“另一侧”在穿过之后仍然成立。初始化时那次 outside 赋值（第 4 节，`tick <= tickCurrent` 才抄全局值）就是为了让这个减法从第一天就有定义。

`snapshotCumulativesInside` 是同一套分支，对象换成 tickCumulative / secondsPerLiquidity / seconds。读 oracle 之前可以先看这个 view，三种位置（价格在区间下、中、上）写在一个函数里。

### 8. Periphery：两条 swap 控制流

`SwapRouter` 继承 `PeripheryImmutableState`（factory、WETH9）、`PeripheryValidation`（deadline）、`PeripheryPaymentsWithFee`、`Multicall`、`SelfPermit`。付款在 `PeripheryPayments.pay`：合约 ETH 够付就 `WETH9.deposit` 再转；`payer == address(this)` 就从路由器余额转；否则 `transferFrom(payer)`。

#### exact input：路由器自己循环

`exactInputSingle` 把参数收成 `abi.encodePacked(tokenIn, fee, tokenOut)`，payer 是 `msg.sender`。

`exactInput` 的多跳在 `while (true)` 里：

- 每一跳只把 `path.getFirstPool()` 放进 callback data。
- 还有下一跳时，`recipient = address(this)`，输出先躺在路由器上。
- 第一跳的 payer 是用户；跳完之后 `payer = address(this)`，下一跳的 `pay` 走“合约已持有”那一支。
- 最后一跳的 recipient 才是用户。循环外检查 `amountOut >= amountOutMinimum`。

`uniswapV3SwapCallback` 里 `amount0Delta > 0` 表示池子在收 token0。和 `tokenIn < tokenOut` 比较，得到这一跳是不是 exact input。exact input 直接 `pay`。

#### exact output：回调里嵌下一跳

path 从输出 token 开始：`abi.encodePacked(tokenOut, fee, tokenIn)`。`exactOutputInternal` 把 `decodeFirstPool` 的第一个地址当 tokenOut，`amountSpecified` 传 `-amountOut`。

多跳在 callback 里继续。`hasMultiplePools` 时 `skipToken()`，再调 `exactOutputInternal(amountToPay, msg.sender, ...)`。此时 `msg.sender` 是上一口池子，内层 swap 的输出直接打进外层池子，凑够外层的余额检查。用户只在最内层（输入 token）被 `pay` 一次。最外层 `swap` 的返回值给不出这个输入量，所以写进存储 `amountInCached`，返回前改回 `type(uint256).max`。

`sqrtPriceLimitX96 == 0` 的 exact output 还会 `require(amountOutReceived == amountOut)`。传了自定义价格限制时，允许少收到，由调用方的 `amountInMaximum` 限制输入。

callback 开头 `require(amount0Delta > 0 || amount1Delta > 0)`。两边 delta 都是 0 的 swap，路由器不接。

### 9. NFT 头寸：core 一份账，manager 又一份账

读 `NonfungiblePositionManager` 的 `mint`、`increaseLiquidity`、`decreaseLiquidity`、`collect`、`burn`。

`mint` 里 `addLiquidity` 的 recipient 是 manager 自己。同一池子、同一 `tickLower/tickUpper` 上的所有 NFT，在 core 里是同一个 position key：`keccak256(manager, tickLower, tickUpper)`。单张 NFT 的流动性和手续费在 `_positions[tokenId]`。

manager 因此自己存 `feeGrowthInside{0,1}LastX128`。`increaseLiquidity` / `decreaseLiquidity` 在 pool 动作之后重读 core 的 fee growth，用 **NFT 自己的 liquidity** 乘 growth 差，加进 NFT 的 `tokensOwed`。公式和 `Position.update` 相同，分母是 `FixedPoint128.Q128`。

`collect`：

1. 还有流动性就 `pool.burn(..., 0)` poke。
2. 用 growth 差更新 NFT 的 `tokensOwed`。
3. 按 `amount{0,1}Max` 截断后 `pool.collect`。core 的 owner 是 manager，所以这笔调用的 `msg.sender` 必须是 manager。
4. core 向下取整，实际转到的 wei 可能略少。NFT 账上减的是请求额 `amount0Collect`，后面才烧得掉 token。见 `collect` 末尾那段注释。

`burn(tokenId)` 要求 `liquidity == 0 && tokensOwed0 == 0 && tokensOwed1 == 0`。它只删 manager 自己的槽并 `_burn`。

`cachePoolKey` 把 `PoolKey` 收成 `uint80 poolId`，position 里只存 id。`positions(tokenId)` 再展开回 token0/token1/fee。

同一笔交易里建池并加流动性，用继承来的 `PoolInitializer.createAndInitializePoolIfNecessary`，再用 `Multicall`（对自身 `delegatecall`）包在一起。池子已存在且 `sqrtPriceX96 != 0` 时，这个函数不会改价。

### 10. 第二遍

| 主题 | 从哪读 | 看什么 |
| --- | --- | --- |
| Oracle | `libraries/Oracle.sol` 的 `write`、`grow`、`observeSingle` | 每区块最多写一次；`grow` 把新槽的 `blockTimestamp` 写成 1，把冷 SSTORE 提前付掉；cardinality 只在 index 走到末尾时升高。二分和插值在 `binarySearch` / `observeSingle` |
| 给 oracle 扩容 | `Pool.increaseObservationCardinalityNext` | 谁都可以调，gas 调用方出 |
| Flash | `Pool.flash` | 先转出，回调里要回 `amount + fee`，fee 用 `mulDivRoundingUp(amount, fee, 1e6)`。多付的部分进 fee growth。`liquidity == 0` 直接 `L`。例子在 `v3-periphery/contracts/examples/PairFlash.sol` |
| 协议费 | `setFeeProtocol`、`collectProtocol` | 只有 factory owner。某个 token 的累计被拿空时故意留下 1 wei，避免槽被清掉 |
| Quoter | `lens/Quoter.sol` | callback 是 `view`，assembly 里 `revert` 出 32 字节报价，外层 `try/catch` 接住。池子状态随内层 revert 丢掉。注释写明不要在链上调。`QuoterV2` 的 revert data 多带成交后的 `sqrtPriceX96` 和跨过的已初始化 tick 数 |
| 链下价格 | `libraries/OracleLibrary.sol` | `consult`、`getQuoteAtTick`，是 `pool.observe` 的封装 |
| V2 迁移 | `V3Migrator.migrate` | `pair.burn` 到 migrator，再 approve 给 NonfungiblePositionManager 去 `mint`。依赖 `@uniswap/v2-core` |
| 付款边角 | `PeripheryPaymentsWithFee`、`SelfPermit` | multicall 里的 `sweepToken` / `unwrapWETH9` / `refundETH`，以及把 permit 和 swap 打进同一笔 |

`TickLens.getPopulatedTicksInWord` 和 `PoolTicksCounter` 是 QuoterV2 数 tick 用的，要改报价再读。

---

## 四条链对照着走一遍

建池并定价：

```text
Factory.createPool
  → Deployer.deploy          // parameters = ...; new Pool{salt}; delete parameters
    → Pool.constructor       // immutables from deployer.parameters()
  → Pool.initialize          // 价格、tick、oracle[0]、unlocked
```

加流动性（经 NPM）：

```text
NonfungiblePositionManager.mint
  → LiquidityManagement.addLiquidity
      → LiquidityAmounts.getLiquidityForAmounts
      → Pool.mint(recipient = manager)
          → _modifyPosition / _updatePosition
          → uniswapV3MintCallback → pay()
  → 写 _positions[tokenId]   // 从 core position 抄 feeGrowthInsideLast
```

exact input 两跳：

```text
SwapRouter.exactInput
  → exactInputInternal hop0   recipient = router, payer = user
      → Pool.swap → callback → pay(user → pool)
  → exactInputInternal hop1   recipient = user,  payer = router
      → Pool.swap → callback → pay(router → pool)
```

exact output 两跳（path 以最终输出 token 开头）：

```text
SwapRouter.exactOutput
  → exactOutputInternal(outer)
      → PoolA.swap → callback
          → exactOutputInternal(inner)   // 输出打给 PoolA
              → PoolB.swap → callback → pay(user → PoolB)
          → amountInCached = 用户支付额
```

撤出：

```text
NPM.decreaseLiquidity → Pool.burn(amount)     // token 进 core tokensOwed，owner 是 manager
NPM.collect
  → Pool.burn(0)                              // poke fee
  → Pool.collect(recipient)
NPM.burn(tokenId)                             // NFT 账已清空之后
```

---

## 读的时候对一下

1. core 的 `mint` 收入的是 liquidity，吐出应付 token。`LiquidityAmounts` 做反向换算。滑点比的是 core 算出来的 token 数量。
2. mint 的 owner 是参数 `recipient`，burn/collect 的 owner 是 `msg.sender`。swap 的 recipient 可以是任意地址，和 position owner 无关。
3. `zeroForOne` 且价格正好落到下一档时，`state.tick = tickNext - 1`。之后用 `slot0.tick` 和区间比较，用的是这个值。
4. 0 流动性区间可以滑过。`feeGrowthGlobal` 的除数是当前步的 liquidity，为 0 时不加 fee。
5. bitmap 一次只搜一个 word。没找到时返回 word 边界，且 `initialized = false`，循环继续。
6. 同一区块 `Oracle.write` 发现时间戳没变就返回。swap 写入用的是这一笔开始时的 tick 和 liquidity。
7. 余额检查是 `<=`。多付可以通过。flash 把多付的部分也算进 fee growth。
8. NPM 与 core 的 tokensOwed 会差几 wei。collect 以请求额扣 NFT 账。
9. `POOL_INIT_CODE_HASH` 在源码里是常量 `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54`。重新编译 core 之后，先确认这个 hash 还和 `PoolAddress.sol` 里的一致，否则 `computeAddress` 对不上已部署的池子。
10. Quoter 把报价放在 revert data 里。`parseRevertReason` 看到长度不是 32 字节，会按错误字符串再 revert。

---

## 建议的一周拆法

| 天 | 读完应该能指着代码讲清楚 |
| --- | --- |
| 1 | factory / deployer / 构造函数 / `initialize` / `Slot0`。用 `PoolAddress` 的公式对一下 salt |
| 2 | `mint` 全路径，含 `Tick.update`、`Position.update`、bitmap flip。用 `TestUniswapV3Callee.mint` 对回调参数 |
| 3 | `burn` + `collect` + `getFeeGrowthInside`。`burn(0)` 做什么，`NP` 什么时候出现 |
| 4 | `swap` 的 while，只跟 exact input、`zeroForOne = true` 的一步。`SwapMath` 和 `SqrtPriceMath` 的对应函数一起看 |
| 5 | 同一循环的 cross、`liquidityNet` 取负、tick 减 1、oracle write 的条件 |
| 6 | `SwapRouter` 的 exact input 多跳和 exact output 多跳。payer 在哪一跳从用户变成合约 |
| 7 | `NonfungiblePositionManager` 四件套。哪一份 fee 在 core，哪一份在 NFT |

某一天如果只想验证一个函数的边界：

- `v3-core/contracts/test/SwapMathTest.sol`
- `v3-core/contracts/test/SqrtPriceMathTest.sol`
- `v3-core/contracts/test/TickBitmapTest.sol`
- `v3-periphery/contracts/test/PathTest.sol`
- `v3-periphery/contracts/test/LiquidityAmountsTest.sol`
