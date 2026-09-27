# 教学借贷池设计

日期：2026-09-26

一个资金池、两种 ERC20：抵押品（WETH）和可借资产（USDC）。存款人提供 USDC，借款人存入 WETH 再借出 USDC。利率用 Compound Jump Rate 的形状，按秒计息。目标是把「存入 → 借出 → 时间过去利息增长 → 价格下跌 → 清算」跑通。

## 范围

做：

- `JumpRateModel`：由现金、总借款、储备金计算每秒借款利率
- `SimplePriceOracle`：部署者可改的美元价格
- `LendingPool`：存款、取款、抵押、借款、还款、计息、清算、提取储备金
- `MockERC20`：无权限 `mint`，只给本地测试和 anvil
- Foundry 测试、部署脚本、中文 README

不做：

- 前端、Chainlink、原生 ETH、多市场 Comptroller、cToken、COMP 挖矿
- 治理、时间锁、暂停、运行中更换利率模型
- 坏账接管。清算若要拿走的抵押品超过余额，整笔交易回滚
- 空池通胀防御。总份额为 0 时汇率固定 1:1。测试先存入流动性再借款

两种演示代币都是 18 位小数。

## 文件

| 路径 | 职责 |
|---|---|
| `src/lending/MockERC20.sol` | 构造时传入 name、symbol。`mint(to, amount)` 无权限 |
| `src/lending/JumpRateModel.sol` | 纯利率。参数在构造时确定，之后不变 |
| `src/lending/SimplePriceOracle.sol` | `asset => 价格`。价格是 1 个代币值多少美元，18 位小数 |
| `src/lending/LendingPool.sol` | 唯一业务状态 |
| `src/lending/README.md` | 链路、公式、示例数字 |
| `test/lending/JumpRateModel.t.sol` | 拐点两侧的利率 |
| `test/lending/LendingPool.t.sol` | 存借、计息、清算 |
| `script/lending/DeployLendingPool.s.sol` | 继承 `BaseScript`，部署并 `saveContract` |

Solidity `pragma ^0.8.24`，许可 `MIT`。OpenZeppelin 用 `@openzeppelin/contracts/...`（本仓库 v5）。外部转账用 `SafeERC20`。会改状态的外部函数加 `ReentrancyGuard`。自定义 `error`，中文 `/// @notice`。

## 部署参数

利率在模型里存「每秒、1e18」。年化先写成 wad，再整除一年的秒数：

```text
SECONDS_PER_YEAR = 365 days = 31_536_000
perSecond = aprWad / SECONDS_PER_YEAR
```

| 名字 | 值 | 含义 |
|---|---|---|
| `BASE_APR` | `0.02e18` | 利用率 0 时借款年化 2% |
| `MULTIPLIER_APR` | `0.10e18` | 拐点以下的斜率系数 |
| `JUMP_MULTIPLIER_APR` | `4.5e18` | 拐点以上的斜率系数 |
| `KINK` | `0.80e18` | 利用率 80% |
| 抵押率 | `0.75e18` | 债务不超过抵押品美元价值的 75% |
| 清算激励 | `1.08e18` | 清算人按所还债务的美元价值多拿 8% 抵押品 |
| close factor | `0.50e18` | 一笔清算最多代还当前债务的 50% |
| 储备金比例 | `0.10e18` | 新增借款利息的 10% 记为储备金 |
| 初始价 | WETH `2000e18`，USDC `1e18` | 1 WETH = 2000 美元，1 USDC = 1 美元 |

由此得到的借款年化（再除以 `SECONDS_PER_YEAR` 才是合约里的每秒利率）：

```text
util ≤ kink:  apr = 2% + util × 10%
util > kink:  apr = 10% + (util - 80%) × 450%
```

核对：

- 利用率 0：2%
- 利用率 80%：2% + 8% = 10%
- 利用率 100%：10% + 20% × 450% = 100%

池子构造参数在部署后不变。预言机价格和储备金提取是仅有的部署后管理操作。

## JumpRateModel

```text
utilization = 0                                         当 borrows == 0 或分母 == 0
utilization = borrows * 1e18 / (cash + borrows - reserves)   其余情况

util ≤ kink:
  borrowRate = basePerSecond + util * multiplierPerSecond / 1e18
util > kink:
  normal = basePerSecond + kink * multiplierPerSecond / 1e18
  borrowRate = normal + (util - kink) * jumpMultiplierPerSecond / 1e18
```

`getBorrowRate(cash, borrows, reserves)` 返回每秒 wad。

`getSupplyRate(cash, borrows, reserves, reserveFactor)` 只用于展示和测试，池子不存储它：

```text
supplyRate = borrowRate * utilization * (1e18 - reserveFactor) / 1e18 / 1e18
```

构造时要求：`kink > 0` 且 `kink ≤ 1e18`。`reserveFactor` 由池子校验，不由模型校验。

## SimplePriceOracle

继承 OpenZeppelin `Ownable`。部署者是 owner。

- `setPrice(asset, price)`：`onlyOwner`，`price == 0` 时回滚
- `getPrice(asset)`：未设置时返回 0

池子在计价时如果读到 0，借款和清算回滚。

## LendingPool 状态

不可变：`collateralToken`、`borrowToken`（两者必须不同）、`oracle`、`model`、`collateralFactor`（`> 0` 且 `≤ 1e18`）、`liquidationIncentive`（`≥ 1e18`）、`closeFactor`（`> 0` 且 `≤ 1e18`）、`reserveFactor`（`≤ 1e18`）。Owner 是部署者，只用于 `reduceReserves`。

可变：

| 字段 | 初值 | 含义 |
|---|---|---|
| `totalShares` | 0 | 存款份额总量 |
| `sharesOf[user]` | 0 | 某存款人的份额 |
| `totalBorrows` | 0 | 含已计利息的总债务（USDC 数量） |
| `totalReserves` | 0 | 协议对池内 USDC 的记账索取权，不是单独余额 |
| `borrowIndex` | `1e18` | 全局借款指数 |
| `accrualTimestamp` | 构造时的 `block.timestamp` | 上次计息时间 |
| `collateralOf[user]` | 0 | 抵押品数量 |
| `principalOf[user]` | 0 | 该用户在其指数下的本金 |
| `userIndexOf[user]` | 0 | 该用户本金对应的 `borrowIndex` |

`cash` 不是存储字段，而是 `borrowToken.balanceOf(address(this))`。有人直接把 USDC 转进池子时，现金增加、存款汇率上升、利用率下降。

## 计息

每个会改余额的外部函数先调用内部 `_accrueInterest()`。另外提供外部 `accrueInterest()`，供测试和链下触发。`delta == 0` 时直接返回。

```text
borrowRate = model.getBorrowRate(cash, totalBorrows, totalReserves)
interest = totalBorrows * borrowRate * delta / 1e18
totalBorrows += interest
totalReserves += interest * reserveFactor / 1e18
borrowIndex += borrowIndex * borrowRate * delta / 1e18
accrualTimestamp = block.timestamp
```

乘除一律向下取整。`totalBorrows == 0` 时 `interest` 为 0，储备金不变，但只要 `borrowRate > 0`，`borrowIndex` 仍会增加。新借款人的 `userIndex` 写成当时的 `borrowIndex`，不承担这段历史。

当前债务（先计息再读，才是最新值）：

```text
principal == 0 时 debt = 0
否则 debt = principal * borrowIndex / userIndex
```

视图 `borrowBalanceStored` 用存储里的指数，不自己计息。

存款汇率：

```text
totalShares == 0 时 exchangeRate = 1e18
否则 exchangeRate = (cash + totalBorrows - totalReserves) * 1e18 / totalShares
```

`cash + totalBorrows - totalReserves` 是存款人的资产索取权。储备金从中扣除，所以存款利率低于借款利率。

## 用户操作

顺序都是：计息、检查、改存储、再转账。

**deposit(assets)**  
`assets == 0` 回滚。`shares = assets * 1e18 / exchangeRate`，向下取整；`shares == 0` 回滚。增加 `totalShares` 和 `sharesOf[msg.sender]`，再 `transferFrom` USDC。

**withdraw(assets)**  
`assets == 0` 回滚。烧掉的份额向上取整：`(assets * 1e18 + exchangeRate - 1) / exchangeRate`。份额不足或 `cash < assets` 时回滚。先减份额再转出 USDC。

**depositCollateral(amount)**  
`amount == 0` 回滚。增加 `collateralOf`，再 `transferFrom` 抵押品。

**withdrawCollateral(amount)**  
`amount == 0` 或余额不足时回滚。先减抵押，再按减完后的抵押和当前债务做健康检查，最后转出抵押品。

**borrow(amount)**  
`amount == 0` 或 `cash < amount` 时回滚。`newDebt = debt + amount`。健康检查用当前抵押和 `newDebt`。通过后把 `principalOf` 写成 `newDebt`，`userIndexOf` 写成当前 `borrowIndex`，`totalBorrows += amount`，再把 USDC 转给借款人。

**repay(borrower, amount)**  
调用者可以替别人还。`amount == type(uint256).max` 表示还清当前债务。实际还款额必须 `> 0` 且 `≤ debt`，超出债务就回滚，不悄悄截断。还清后 `principalOf = 0`；否则 `principalOf = debt - repay`，`userIndexOf = borrowIndex`。`totalBorrows` 减去实际还款额，再 `transferFrom` USDC。

健康检查（借款和提取抵押之后必须成立）：

```text
collateralUsd = collateralAmount * collateralPrice / 1e18
debtUsd = debt * borrowPrice / 1e18
maxDebtUsd = collateralUsd * collateralFactor / 1e18
要求 debtUsd ≤ maxDebtUsd
任一价格为 0 则回滚
```

视图 `getAccountLiquidity(user)` 不计入息，返回 `(liquidityUsd, shortfallUsd)`：

```text
liquidityUsd = maxDebtUsd > debtUsd ? maxDebtUsd - debtUsd : 0
shortfallUsd = debtUsd > maxDebtUsd ? debtUsd - maxDebtUsd : 0
```

这里的 `debt` 用 `borrowBalanceStored`。测试要看最新偿付能力时，先调用 `accrueInterest()`。

## 清算

`liquidate(borrower, repayAmount)`：

1. 计息。
2. 读存储债务。债务为 0，或 `shortfallUsd == 0`，则回滚。借款人自己也可以清算自己。
3. `maxRepay = debt * closeFactor / 1e18`。`repayAmount == 0` 或 `repayAmount > maxRepay` 则回滚，不把超额部分截成 50%。
4. 抵押品数量：

```text
repayUsd = repayAmount * borrowPrice / 1e18
seizeUsd = repayUsd * liquidationIncentive / 1e18
seize = seizeUsd * 1e18 / collateralPrice
```

`seize == 0` 或 `seize > collateralOf[borrower]` 则回滚。

5. 减少抵押和债务，记账方式与 `repay` 相同。`totalBorrows` 减去 `repayAmount`。
6. 把抵押品转给清算人，再从清算人拉走 USDC。

示例（测试用这组数，且在借款后的同一时间戳清算，避免利息把 800 改掉）：池内 1000 USDC，借出 800 USDC，抵押 1 WETH。价格从 2000 降到 500 时，抵押品值 500 美元，借款上限 375 美元，债务 800 美元，可以清算。50% 即 400 USDC，清算人得到 `400 * 1.08 / 500 = 0.864` WETH。价格若降到 100，50% 清算要 4.32 WETH，超过余额，这一笔必须回滚；更小的 `repayAmount` 仍可成功。

## 储备金

`reduceReserves(amount)` 仅 owner。先计息。`amount ≤ totalReserves` 且 `amount ≤ cash`。减少 `totalReserves` 后把 USDC 转给 owner。存款汇率的分子同时减去现金和储备金，汇率不变。

没有人调用时，储备金只是抬高了利用率、压低了存款汇率，对应的 USDC 留在池子里。

## 事件与错误

事件：`Deposit`、`Withdraw`、`CollateralDeposited`、`CollateralWithdrawn`、`Borrow`、`Repay`、`Liquidate`、`AccrueInterest`、`ReservesReduced`。参数至少包含操作人和金额；`AccrueInterest` 带新的 `borrowIndex`、`totalBorrows`、`totalReserves`。

错误按条件分开，至少覆盖：数量为 0、份额为 0、份额不足、现金不足、抵押不足、不健康、价格为 0、债务为 0、还款超过债务、没有短亏、还款超过 close factor、扣押为 0、扣押超过抵押、两种代币相同、构造参数越界。

## 测试

`JumpRateModel`：

- 利用率 0、80%、100% 的每秒利率等于「部署参数」一节的年化除以 `SECONDS_PER_YEAR` 的整数结果
- 90% 的利率高于 80%
- 拐点以上每 1% 利用率的利率增量大于拐点以下

`LendingPool`：

- 空池存款 1:1 得到份额
- 已有存款和借款时，`vm.warp` 并计息后汇率上升；下一个人存入与第一笔相同的 USDC，得到的份额更少。没有借款时利息为 0，汇率不变，不能用来断言这件事
- 先存入至少 1500 USDC。抵押 1 WETH、价格 2000 时，借 1500 USDC 成功（刚好 75%），再多 1 wei 回滚
- 存款、抵押、借款都在同一个 `block.timestamp` 里完成，然后 `vm.warp` 一年并 `accrueInterest`。存款 1000、借款 800：`totalBorrows` 与借款人债务都增加 `800e18 * borrowRate * SECONDS_PER_YEAR / 1e18`（借款时 `borrowIndex` 仍是 `1e18`），储备金是这笔利息的 10%，存款汇率上升。`borrowRate` 用计息前 `getBorrowRate` 的返回值
- 另一池把利用率配到 80% 以上，相同的 warp 之后 `borrowIndex` 增量更大
- 价格仍是 2000 时清算回滚
- 价格降到 500 时，按上面的例子清算，借款人债务和抵押下降，清算人得到 0.864 WETH
- `repayAmount` 比 `maxRepay` 大 1 wei 时回滚
- 价格降到 100 时，50% 债务对应的扣押超过 1 WETH，回滚；更小的还款额成功
- 有债务时把抵押取到不健康，回滚
- `reduceReserves` 把记账的储备金转给 owner，存款汇率不变
- 非 owner 不能 `setPrice`，也不能 `reduceReserves`

## 部署脚本

`DeployLendingPool`：

1. `new MockERC20("Wrapped Ether", "WETH")`
2. `new MockERC20("USD Coin", "USDC")`
3. `new SimplePriceOracle(deployer)`，设置两种价格
4. `new JumpRateModel(...)`，传入每秒利率和 kink
5. `new LendingPool(...)`，传入两种代币、预言机、模型、四项风险参数、owner

每个地址都 `saveContract`。脚本头注释写上和 `DeploySimpleVault` 一样的 `forge script ... && cat ./deployments/LATEST.txt` 用法。
