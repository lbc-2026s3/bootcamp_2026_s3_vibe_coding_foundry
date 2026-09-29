# 教学预测市场设计（类 Polymarket YES/NO + CPAMM）

日期：2026-09-29

二元结果市场：每个问题有 YES / NO 两种结果份额。用户用任意 ERC20 抵押品 `split` 成等量 YES+NO，可在恒定乘积池中互相兑换，也可 `merge` 退回抵押品。截止后由 oracle（Owner 式地址）`resolve`，赢家按 1:1 份额兑付抵押品。Factory 可创建多个市场。目标是把「完整结果集 → AMM 定价 → 结算兑付」跑通，复杂度对齐本仓库 `option/` 模块。

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

- swap 后 `yesReserve * noReserve` 不下降（fee 使 k 非减）
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
- fuzz：split/merge；swap 后 k 非减；redeem 不超过余额

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
