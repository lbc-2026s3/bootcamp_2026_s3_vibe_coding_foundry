# 教学预测市场设计（类 Polymarket YES/NO + CPAMM）

日期：2026-09-29

二元结果市场：每个问题有 YES / NO 两种结果份额。用户用任意 ERC20 抵押品 `split` 成等量 YES+NO，可在恒定乘积池中互相兑换，也可 `merge` 退回抵押品。截止后由 oracle（Owner 式地址）`resolve`，赢家按 1:1 份额兑付抵押品。Factory 可创建多个市场。目标是把「完整结果集 → AMM 定价 → 结算兑付」跑通，复杂度对齐本仓库 `option/` 模块。

## 什么是 CPAMM

**CPAMM** = **C**onstant **P**roduct **A**utomated **M**arket **M**aker（恒定乘积自动做市商），即 Uniswap V2 同款定价模型。

核心不变量：池中两种资产的储备量乘积保持恒定（忽略手续费时）

\[
x \cdot y = k
\]

本市场里 \(x\) = `yesReserve`，\(y\) = `noReserve`。用户用 YES 换 NO（或反过来）时：

1. 把 `amountIn`（扣 0.3% fee 后）加入对应储备
2. 按上式算出另一侧要减少多少，即为 `amountOut`
3. fee 留在池内不参与兑出，\(k\) 因此上升，收益归 LP

相对订单簿：无需对手方挂单，价格由储备比例即时给出。教学上用它给 YES/NO 份额定价，而不是接外部预言机喂价。

### `priceYes` 推导

记 \(R_y\) = `yesReserve`，\(R_n\) = `noReserve`。忽略 fee，恒定乘积：

\[
R_y \cdot R_n = k \quad (k \text{ 为常数})
\]

#### 1. 有限笔交易的精确汇率

用户用 NO 买 YES：从池中取走 \(\Delta_y > 0\) 份 YES，同时向池中注入 \(\Delta_n > 0\) 份 NO。交易后储备仍须满足乘积不变：

\[
(R_y - \Delta_y)\,(R_n + \Delta_n) = R_y R_n
\]

解出 \(\Delta_n\)：

\[
R_n + \Delta_n = \frac{R_y R_n}{R_y - \Delta_y}
\implies
\Delta_n
= R_n\left(\frac{R_y}{R_y - \Delta_y} - 1\right)
= R_n \cdot \frac{\Delta_y}{R_y - \Delta_y}
\]

于是「每买 1 份 YES 平均要付多少 NO」为：

\[
\frac{\Delta_n}{\Delta_y} = \frac{R_n}{R_y - \Delta_y}
\]

\(\Delta_y\) 越大，分母越小，单价越高（滑点）。

#### 2. 即期汇率（交易量趋于 0）

令 \(\Delta_y \to 0^+\)：

\[
\lim_{\Delta_y \to 0^+} \frac{\Delta_n}{\Delta_y} = \frac{R_n}{R_y}
\]

即：**边际上，1 份 YES 兑换 \(R_n / R_y\) 份 NO**。\(R_y\) 越小，YES 越贵。

（若写成 \(\mathrm{d}R_n / \mathrm{d}R_y\)，\(\mathrm{d}\) 表示该极限下的无穷小增量，不是某个函数名。）

#### 3. 归一化为抵押品价格

`split`/`merge` 保证 **1 YES + 1 NO = 1 抵押品**，故以抵押品计价的公允价 \(P_y, P_n\) 满足完备性：

\[
P_y + P_n = 1 \tag{A}
\]

池内相对价格应等于即期汇率（YES 相对 NO 的兑价）：

\[
\frac{P_y}{P_n} = \frac{R_n}{R_y}
\iff
P_y = P_n \cdot \frac{R_n}{R_y} \tag{B}
\]

将 (B) 代入 (A)：

\[
P_n \cdot \frac{R_n}{R_y} + P_n = 1
\implies
P_n\left(\frac{R_n + R_y}{R_y}\right) = 1
\implies
P_n = \frac{R_y}{R_y + R_n},\qquad
P_y = \frac{R_n}{R_y + R_n}
\]

合约（定点 1e18）：`priceYes = noReserve * 1e18 / (yesReserve + noReserve)`。

## 范围

做：

- `OutcomeToken`：仅 market 可 mint/burn 的 ERC20
- `PredictionMarket`：split / merge / CPAMM（含 LP）/ resolve / redeem
- `PredictionMarketFactory`：创建市场并登记
- Foundry 单元 + fuzz 测试、部署脚本（可部署 MockUSDC）

不做：

- 前端、Gnosis CTF、UMA 争议、订单簿、多结果（>2）、升级代理、pause、治理
- Chainlink / 自动结算；oracle 为中心化地址（教学信任假设）
- 独立 LP ERC20（用内部 `lpBalances` + `totalLp`）
- 手续费抽成给协议方（0.3% swap fee 全留在池内给 LP）

## 文件

| 路径 | 职责 |
|---|---|
| `src/prediction/OutcomeToken.sol` | YES/NO 份额；`mint`/`burn` 仅 market |
| `src/prediction/PredictionMarket.sol` | 单市场业务状态与生命周期 |
| `src/prediction/PredictionMarketFactory.sol` | `createMarket` + `markets[]` |
| `script/prediction/DeployPredictionMarket.s.sol` | 继承 `BaseScript`；可选 MockUSDC；部署 factory 并示例建场 |
| `test/prediction/PredictionMarket.t.sol` | 主流程、边界、fuzz |

Solidity `pragma ^0.8.24`，许可 `MIT`。OpenZeppelin v5（Market 用自定义 `onlyOracle`，不用升级代理）。外部代币用 `SafeERC20`。资金进出加 `ReentrancyGuard`。自定义 `error`，中文 `/// @notice`。

## 架构

```text
PredictionMarketFactory
  createMarket(question, collateral, deadline, oracle)
       │
       ▼
PredictionMarket
  ├── OutcomeToken yes
  ├── OutcomeToken no
  ├── IERC20 collateral
  ├── yesReserve / noReserve / lpBalances / totalLp
  └── status: Open → TradingClosed → Resolved
```

生命周期：

1. **Open**（`block.timestamp < deadline`）：split、merge、add/removeLiquidity、swap
2. **TradingClosed**（`timestamp >= deadline` 且未 resolve）：上述全部禁用；仅 oracle 可 `resolve`
3. **Resolved**：用户可 `redeem` 赢家份额；允许 LP `removeLiquidity` 取出 YES/NO 后再 redeem 赢家侧

## 会计与精度

- 份额 decimals = 抵押品 `IERC20Metadata.decimals()`（构造 OutcomeToken 时传入）
- `split(amount)`：转入 `amount` 抵押品，mint `amount` YES + `amount` NO
- `merge(amount)`：burn `amount` YES + `amount` NO，转出 `amount` 抵押品
- 赢家 `redeem`：burn 持有的赢家份额，转出等量抵押品
- CPAMM：`amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee)`，`FEE_BPS = 30`（0.3%，分母 10_000）
- YES 隐含价格（1e18）：`priceYes = noReserve * 1e18 / (yesReserve + noReserve)`（两储备皆 > 0）

不变量（测试断言）：

- swap 后 `yesReserve * noReserve` 上升（fee 留池；断言用 ≥ 防舍入）
- `split`/`merge` roundtrip 后用户抵押品与份额守恒（忽略他人活动）
- resolve 后可 redeem 总量不超过合约抵押品余额；超额 redeem revert

## 接口摘要

### OutcomeToken

- `constructor(name, symbol, decimals_, market)`
- `mint(to, amount)` / `burn(from, amount)` — 仅 `msg.sender == market`

### PredictionMarket

| 函数 | 调用者 | 条件 |
|---|---|---|
| `split(amount)` | 任意 | Open；amount > 0 |
| `merge(amount)` | 任意 | Open |
| `addLiquidity(yesAmount, noAmount, minLp)` | 任意 | Open；首次任意比例；其后按储备比例 |
| `removeLiquidity(lpAmount, minYes, minNo)` | LP | 仅 Open 与 Resolved（TradingClosed 期间禁止） |
| `swapYesForNo(amountIn, minOut)` / `swapNoForYes(...)` | 任意 | Open；有流动性 |
| `resolve(bool yesWins)` | oracle | `timestamp >= deadline`；未 resolve |
| `redeem()` | 任意 | Resolved；burn 全部赢家余额兑付 |
| `getYesPrice()` | view | 储备为 0 时 revert `InsufficientLiquidity` |

构造：`(string question, address collateral, uint256 deadline, address oracle)`。`deadline` 必须 `> block.timestamp`。`oracle != 0`。

### PredictionMarketFactory

- `createMarket(string question, address collateral, uint256 deadline, address oracle) returns (address market)`
  - `oracle == address(0)` → `oracle = msg.sender`
  - 部署 Market（Market 内再部署两个 OutcomeToken）
  - `markets.push`；emit `MarketCreated`
- `markets(uint256)` / `marketCount()` view
- 不限制谁可以 create（permissionless）

## 错误与事件

错误：`ZeroAddress` · `ZeroAmount` · `InvalidDeadline` · `MarketClosed` · `DeadlineNotReached` · `AlreadyResolved` · `NotResolved` · `NotOracle` · `Slippage` · `InsufficientLiquidity` · `NothingToRedeem` · `InvalidLiquidityRatio`

事件：`MarketCreated`（factory）· `Split` · `Merged` · `LiquidityAdded` · `LiquidityRemoved` · `Swapped` · `Resolved` · `Redeemed`

## 部署脚本

环境变量（可选）：

- `COLLATERAL` — 未设则部署 MockUSDC（6 decimals，mint 给 deployer）
- `QUESTION` — 默认示例问题字符串
- `DEADLINE` — 默认 `block.timestamp + 7 days`
- `ORACLE` — 默认 deployer

脚本：部署 Factory →（可选）MockUSDC → `createMarket` → `saveContract` 记录 Factory、Market、YES、NO、Collateral。

## 测试计划

- createMarket 登记与参数
- split/merge roundtrip
- 首次与后续 addLiquidity；removeLiquidity
- swap 改变 getYesPrice；minOut slippage revert
- deadline 后交易类 revert；过早 resolve revert
- 非 oracle resolve revert；二次 resolve revert
- YES 赢 / NO 赢各自 redeem；输家 NothingToRedeem
- resolve 后 LP 撤出再 redeem
- fuzz：split/merge；swap 后 k 上升；redeem 不超过余额

不测 OpenZeppelin ERC20 内部行为。

## CROPS 简记

| 维度 | 选择 | 妥协 |
|---|---|---|
| Censorship | 建场与交易 permissionless | oracle 可拒不 resolve 或错判 |
| Open Source | 全部合约在本仓库 | — |
| Privacy | 链上公开持仓与交易 | 教学可接受 |
| Security | CEI + ReentrancyGuard + SafeERC20 | 中心化 oracle；无 pause |

用户逃生：截止前 `merge` 完整集，或卖出后退出。

## 实现备注

- Market 用 `new OutcomeToken(...)` 两次，避免工厂再传 token 地址的循环依赖
- LP 首次：`lpMinted = sqrt(yesAmount * noAmount)`（Uniswap V2 式）；后续按 `min(yesAmount * totalLp / yesReserve, noAmount * totalLp / noReserve)`
- 最小流动性锁死：首次 mint 时将 `MINIMUM_LIQUIDITY = 1000` 记到 `address(1)`（不可赎回），教学级防虚增
- 无前端交付
