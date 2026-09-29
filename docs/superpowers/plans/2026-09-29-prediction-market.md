# Prediction Market Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Foundry 项目中实现教学级二元预测市场：Factory 建场、抵押品 split/merge 为 YES/NO、CPAMM 交易、oracle resolve、赢家 redeem。

**Architecture:** `PredictionMarketFactory` permissionless 部署 `PredictionMarket`；每个市场自建两个 `OutcomeToken`。完整结果集锁定抵押品；池内用恒定乘积交易 YES↔NO（0.3% fee 归 LP）；截止后 oracle 裁定，赢家 1:1 兑付抵押品。

**Tech Stack:** Solidity `^0.8.24`（foundry.toml solc `0.8.34`）、Foundry、OpenZeppelin Contracts v5（`ERC20`、`SafeERC20`、`ReentrancyGuard`、`Math`）。

**Spec:** `docs/superpowers/specs/2026-09-29-prediction-market-design.md`

## Global Constraints

- 工作目录：`bootcamp_2026_s3_vibe_coding_foundry`。所有 `forge` 命令在此目录执行。
- `pragma solidity ^0.8.24;`，许可 `MIT`。导入用 `@openzeppelin/contracts/...`（本仓库 remappings 已配置）。
- 份额 decimals = 抵押品 `IERC20Metadata.decimals()`；测试用 MockUSDC **6 decimals**。
- 外部代币一律 `SafeERC20`。资金进出函数加 `nonReentrant`；Checks-Effects-Interactions。
- 自定义 `error`；公开函数中文 `/// @notice`。
- `FEE_BPS = 30`（0.3%，分母 `10_000`）。`MINIMUM_LIQUIDITY = 1000` 永久记在 `address(1)`。
- LP 用内部 `mapping(address => uint256) lpBalances` + `totalLp`，不另发 ERC20。
- 不做前端、CTF、UMA、订单簿、多结果、代理升级、pause、协议抽成。
- 风格对齐 `src/option/`：目录三分 `src/` · `script/` · `test/`，部署脚本继承 `BaseScript`。

## File Structure

| 文件 | 职责 |
|---|---|
| `src/prediction/OutcomeToken.sol` | 仅 market 可 mint/burn 的结果份额 ERC20 |
| `src/prediction/PredictionMarket.sol` | split/merge、LP、swap、resolve、redeem |
| `src/prediction/PredictionMarketFactory.sol` | `createMarket` + 登记 |
| `script/prediction/DeployPredictionMarket.s.sol` | 部署 factory / mock / 示例市场 |
| `test/prediction/OutcomeToken.t.sol` | OutcomeToken 权限与 decimals |
| `test/prediction/PredictionMarket.t.sol` | 市场主流程、边界、fuzz |
| `test/prediction/PredictionMarketFactory.t.sol` | 建场与登记 |

每个任务结束时该任务测试通过，且不破坏先前测试。

---

### Task 1: OutcomeToken

**Files:**
- Create: `src/prediction/OutcomeToken.sol`
- Test: `test/prediction/OutcomeToken.t.sol`

**Interfaces:**
- Consumes: OpenZeppelin `ERC20`
- Produces:
  - `constructor(string memory name_, string memory symbol_, uint8 decimals_, address market_)`
  - `function mint(address to, uint256 amount) external`
  - `function burn(address from, uint256 amount) external`
  - `function decimals() public view override returns (uint8)`
  - errors: `NotMarket`, `ZeroAddress`

- [ ] **Step 1: Write the failing test**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OutcomeToken} from "../../src/prediction/OutcomeToken.sol";

contract OutcomeTokenTest is Test {
    address internal market = makeAddr("market");
    address internal alice = makeAddr("alice");
    OutcomeToken internal token;

    function setUp() public {
        token = new OutcomeToken("Yes", "YES", 6, market);
    }

    function test_DecimalsMatchConstructor() public view {
        assertEq(token.decimals(), 6);
    }

    function test_MarketCanMintAndBurn() public {
        vm.prank(market);
        token.mint(alice, 100e6);
        assertEq(token.balanceOf(alice), 100e6);

        vm.prank(market);
        token.burn(alice, 40e6);
        assertEq(token.balanceOf(alice), 60e6);
    }

    function test_RevertWhen_NonMarketMints() public {
        vm.prank(alice);
        vm.expectRevert(OutcomeToken.NotMarket.selector);
        token.mint(alice, 1);
    }

    function test_RevertWhen_ZeroMarket() public {
        vm.expectRevert(OutcomeToken.ZeroAddress.selector);
        new OutcomeToken("Yes", "YES", 6, address(0));
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `forge test --match-path test/prediction/OutcomeToken.t.sol -vv`

Expected: FAIL（找不到 `OutcomeToken`）

- [ ] **Step 3: Write minimal implementation**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice 预测市场结果份额；仅所属 market 可 mint/burn。
contract OutcomeToken is ERC20 {
    address public immutable market;
    uint8 private immutable _decimals;

    error NotMarket();
    error ZeroAddress();

    modifier onlyMarket() {
        if (msg.sender != market) revert NotMarket();
        _;
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_, address market_)
        ERC20(name_, symbol_)
    {
        if (market_ == address(0)) revert ZeroAddress();
        market = market_;
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice 铸造份额给 `to`（仅 market）。
    function mint(address to, uint256 amount) external onlyMarket {
        _mint(to, amount);
    }

    /// @notice 从 `from` 销毁份额（仅 market）。
    function burn(address from, uint256 amount) external onlyMarket {
        _burn(from, amount);
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `forge test --match-path test/prediction/OutcomeToken.t.sol -vv`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/prediction/OutcomeToken.sol test/prediction/OutcomeToken.t.sol
git commit -m "feat(prediction): add OutcomeToken with market-only mint/burn"
```

---

### Task 2: PredictionMarket — 构造 + split/merge

**Files:**
- Create: `src/prediction/PredictionMarket.sol`（本任务只实现构造、`split`、`merge` 与生命周期 helpers）
- Test: `test/prediction/PredictionMarket.t.sol`（本任务相关用例）

**Interfaces:**
- Consumes: `OutcomeToken`；`IERC20` / `IERC20Metadata`；`SafeERC20`；`ReentrancyGuard`
- Produces（本任务）：
  - `constructor(string memory question_, address collateral_, uint256 deadline_, address oracle_)`
  - `function split(uint256 amount) external`
  - `function merge(uint256 amount) external`
  - public immutables / state: `question`, `collateral`, `deadline`, `oracle`, `yesToken`, `noToken`, `resolved`, `yesWins`
  - errors used now: `ZeroAddress`, `ZeroAmount`, `InvalidDeadline`, `MarketClosed`
  - events: `Split`, `Merged`

实现要点：

- 构造里 `new OutcomeToken(...)` 两次，`decimals` 取自 `IERC20Metadata(collateral_).decimals()`；name/symbol 用 `"YES"` / `"NO"`。
- `_tradingOpen()`：`!resolved && block.timestamp < deadline`。
- `split`：`collateral.safeTransferFrom` → `yes.mint` + `no.mint`。
- `merge`：先 `burn` 再 `safeTransfer` 抵押品。
- 本任务文件只含已测函数；后续任务用追加方式加 LP/swap/resolve。

- [ ] **Step 1: Write failing tests for split/merge**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PredictionMarket} from "../../src/prediction/PredictionMarket.sol";
import {OutcomeToken} from "../../src/prediction/OutcomeToken.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract PredictionMarketTest is Test {
    MockUSDC internal usdc;
    PredictionMarket internal market;
    address internal oracle = makeAddr("oracle");
    address internal alice = makeAddr("alice");
    uint256 internal deadline;

    function setUp() public {
        usdc = new MockUSDC();
        deadline = block.timestamp + 7 days;
        market = new PredictionMarket("Will ETH > 5k?", address(usdc), deadline, oracle);
        usdc.mint(alice, 1_000_000e6);
    }

    function test_ConstructorDeploysOutcomeTokens() public view {
        assertEq(market.oracle(), oracle);
        assertEq(address(market.collateral()), address(usdc));
        assertEq(OutcomeToken(address(market.yesToken())).decimals(), 6);
        assertEq(OutcomeToken(address(market.yesToken())).market(), address(market));
    }

    function test_SplitMintsEqualYesAndNo() public {
        vm.startPrank(alice);
        usdc.approve(address(market), 100e6);
        market.split(100e6);
        vm.stopPrank();

        assertEq(market.yesToken().balanceOf(alice), 100e6);
        assertEq(market.noToken().balanceOf(alice), 100e6);
        assertEq(usdc.balanceOf(address(market)), 100e6);
    }

    function test_MergeBurnsAndReturnsCollateral() public {
        vm.startPrank(alice);
        usdc.approve(address(market), 100e6);
        market.split(100e6);
        market.merge(40e6);
        vm.stopPrank();

        assertEq(market.yesToken().balanceOf(alice), 60e6);
        assertEq(market.noToken().balanceOf(alice), 60e6);
        assertEq(usdc.balanceOf(alice), 1_000_000e6 - 60e6);
    }

    function test_RevertWhen_SplitAfterDeadline() public {
        vm.warp(deadline);
        vm.startPrank(alice);
        usdc.approve(address(market), 1e6);
        vm.expectRevert(PredictionMarket.MarketClosed.selector);
        market.split(1e6);
        vm.stopPrank();
    }
}
```

- [ ] **Step 2: Run tests — expect fail**

Run: `forge test --match-path test/prediction/PredictionMarket.t.sol -vv`

Expected: FAIL（找不到 `PredictionMarket`）

- [ ] **Step 3: Implement constructor + split + merge**

文件中预留后续状态字段（本任务可不写入 LP/swap 逻辑）：

```solidity
string public question;
IERC20 public immutable collateral;
uint256 public immutable deadline;
address public immutable oracle;
OutcomeToken public immutable yesToken;
OutcomeToken public immutable noToken;
bool public resolved;
bool public yesWins;
```

完整 `split` / `merge` + `nonReentrant` + 上述 errors/events。

- [ ] **Step 4: Run tests — expect pass**

Run: `forge test --match-path test/prediction/PredictionMarket.t.sol -vv`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/prediction/PredictionMarket.sol test/prediction/PredictionMarket.t.sol
git commit -m "feat(prediction): add market split and merge"
```

---

### Task 3: PredictionMarket — add/removeLiquidity

**Files:**
- Modify: `src/prediction/PredictionMarket.sol`
- Modify: `test/prediction/PredictionMarket.t.sol`

**Interfaces:**
- Consumes: Task 2 的 market + outcome tokens
- Produces:
  - `function addLiquidity(uint256 yesAmount, uint256 noAmount, uint256 minLp) external returns (uint256 lpMinted)`
  - `function removeLiquidity(uint256 lpAmount, uint256 minYes, uint256 minNo) external returns (uint256 yesOut, uint256 noOut)`
  - state: `yesReserve`, `noReserve`, `totalLp`, `lpBalances`
  - constants: `FEE_BPS = 30`, `MINIMUM_LIQUIDITY = 1000`
  - errors: `Slippage`, `InsufficientLiquidity`, `InvalidLiquidityRatio`
  - events: `LiquidityAdded`, `LiquidityRemoved`
  - `_liquidityActionAllowed()`：Open（`!resolved && ts < deadline`）或 Resolved；TradingClosed 禁止

公式：

- 首次（`totalLp == 0`）：`lpMinted = Math.sqrt(yesAmount * noAmount)`；要求 `lpMinted > MINIMUM_LIQUIDITY`；`lpBalances[address(1)] = MINIMUM_LIQUIDITY`；用户得 `lpMinted - MINIMUM_LIQUIDITY`；`totalLp = lpMinted`。
- 后续：`lpMinted = min(yesAmount * totalLp / yesReserve, noAmount * totalLp / noReserve)`；若为 0 → `InvalidLiquidityRatio`。
- 转入 YES/NO 到 market，增加储备；撤出按 `lpAmount * reserve / totalLp`。
- 使用 `Math.sqrt` from `@openzeppelin/contracts/utils/math/Math.sol`。

- [ ] **Step 1: Add failing liquidity tests**

```solidity
function _split(address user, uint256 amount) internal {
    usdc.mint(user, amount);
    vm.startPrank(user);
    usdc.approve(address(market), amount);
    market.split(amount);
    vm.stopPrank();
}

function _seedPool(address user, uint256 yesAmount, uint256 noAmount) internal {
    _split(user, yesAmount > noAmount ? yesAmount : noAmount);
    vm.startPrank(user);
    market.yesToken().approve(address(market), yesAmount);
    market.noToken().approve(address(market), noAmount);
    market.addLiquidity(yesAmount, noAmount, 0);
    vm.stopPrank();
}

function test_AddLiquiditySeedsReserves() public {
    _split(alice, 200e6);
    vm.startPrank(alice);
    market.yesToken().approve(address(market), 100e6);
    market.noToken().approve(address(market), 100e6);
    uint256 lp = market.addLiquidity(100e6, 100e6, 0);
    vm.stopPrank();

    assertEq(market.yesReserve(), 100e6);
    assertEq(market.noReserve(), 100e6);
    assertEq(lp, market.totalLp() - market.MINIMUM_LIQUIDITY());
    assertEq(market.lpBalances(alice), lp);
}

function test_RemoveLiquidityReturnsProRata() public {
    _seedPool(alice, 100e6, 100e6);
    uint256 lp = market.lpBalances(alice);

    vm.prank(alice);
    (uint256 y, uint256 n) = market.removeLiquidity(lp, 0, 0);

    assertGt(y, 0);
    assertGt(n, 0);
    assertEq(market.lpBalances(alice), 0);
}

function test_RevertWhen_RemoveDuringTradingClosed() public {
    _seedPool(alice, 100e6, 100e6);
    vm.warp(deadline);
    vm.prank(alice);
    vm.expectRevert(PredictionMarket.MarketClosed.selector);
    market.removeLiquidity(1, 0, 0);
}
```

- [ ] **Step 2: Run — expect fail**

Run: `forge test --match-path test/prediction/PredictionMarket.t.sol --match-test test_AddLiquidity -vv`

Expected: FAIL（函数不存在）

- [ ] **Step 3: Implement addLiquidity / removeLiquidity**

- [ ] **Step 4: Run full PredictionMarket tests — expect pass**

Run: `forge test --match-path test/prediction/PredictionMarket.t.sol -vv`

- [ ] **Step 5: Commit**

```bash
git add src/prediction/PredictionMarket.sol test/prediction/PredictionMarket.t.sol
git commit -m "feat(prediction): add CPAMM liquidity provision"
```

---

### Task 4: PredictionMarket — swap + getYesPrice

**Files:**
- Modify: `src/prediction/PredictionMarket.sol`
- Modify: `test/prediction/PredictionMarket.t.sol`

**Interfaces:**
- Produces:
  - `function swapYesForNo(uint256 amountIn, uint256 minOut) external returns (uint256 amountOut)`
  - `function swapNoForYes(uint256 amountIn, uint256 minOut) external returns (uint256 amountOut)`
  - `function getYesPrice() public view returns (uint256)` — `noReserve * 1e18 / (yesReserve + noReserve)`
  - `function previewSwapYesForNo(uint256 amountIn) public view returns (uint256)`
  - `function previewSwapNoForYes(uint256 amountIn) public view returns (uint256)`
  - event `Swapped(address indexed trader, bool yesForNo, uint256 amountIn, uint256 amountOut)`

公式：

```text
amountInWithFee = amountIn * (10_000 - FEE_BPS) / 10_000
amountOut = amountInWithFee * reserveOut / (reserveIn + amountInWithFee)
```

仅 Open 可 swap；储备为 0 → `InsufficientLiquidity`；`amountOut < minOut` → `Slippage`。  
推荐顺序：`transferFrom` in → 更新储备 → `transfer` out；函数加 `nonReentrant`。

- [ ] **Step 1: Add failing swap tests**

```solidity
function test_SwapYesForNoMovesPrice() public {
    _seedPool(alice, 100e6, 100e6);
    uint256 priceBefore = market.getYesPrice();

    address bob = makeAddr("bob");
    _split(bob, 50e6);
    vm.startPrank(bob);
    market.yesToken().approve(address(market), 10e6);
    market.swapYesForNo(10e6, 0);
    vm.stopPrank();

    assertLt(market.getYesPrice(), priceBefore);
}

function test_SwapIncreasesK() public {
    _seedPool(alice, 100e6, 100e6);
    uint256 kBefore = market.yesReserve() * market.noReserve();
    address bob = makeAddr("bob");
    _split(bob, 20e6);
    vm.startPrank(bob);
    market.yesToken().approve(address(market), 5e6);
    market.swapYesForNo(5e6, 0);
    vm.stopPrank();
    assertGe(market.yesReserve() * market.noReserve(), kBefore);
}

function test_RevertWhen_SwapSlippage() public {
    _seedPool(alice, 100e6, 100e6);
    address bob = makeAddr("bob");
    _split(bob, 10e6);
    vm.startPrank(bob);
    market.yesToken().approve(address(market), 1e6);
    vm.expectRevert(PredictionMarket.Slippage.selector);
    market.swapYesForNo(1e6, type(uint256).max);
    vm.stopPrank();
}
```

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement swaps + getYesPrice + preview**

- [ ] **Step 4: Run PredictionMarket tests — pass**

- [ ] **Step 5: Commit**

```bash
git add src/prediction/PredictionMarket.sol test/prediction/PredictionMarket.t.sol
git commit -m "feat(prediction): add YES/NO CPAMM swaps"
```

---

### Task 5: PredictionMarket — resolve + redeem

**Files:**
- Modify: `src/prediction/PredictionMarket.sol`
- Modify: `test/prediction/PredictionMarket.t.sol`

**Interfaces:**
- Produces:
  - `function resolve(bool yesWins_) external`
  - `function redeem() external`
  - errors: `NotOracle`, `DeadlineNotReached`, `AlreadyResolved`, `NotResolved`, `NothingToRedeem`
  - events: `Resolved`, `Redeemed`

Resolved 后允许 `removeLiquidity`；`split`/`merge`/`swap`/`addLiquidity` 仍关闭。

- [ ] **Step 1: Add failing resolve/redeem tests**

```solidity
function test_ResolveAndRedeemYesWins() public {
    _split(alice, 100e6);
    vm.warp(deadline);
    vm.prank(oracle);
    market.resolve(true);

    uint256 before = usdc.balanceOf(alice);
    vm.prank(alice);
    market.redeem();
    assertEq(usdc.balanceOf(alice), before + 100e6);
    assertEq(market.yesToken().balanceOf(alice), 0);
}

function test_LoserRedeemReverts() public {
    address bob = makeAddr("bob");
    _split(bob, 50e6);
    vm.prank(bob);
    market.yesToken().transfer(alice, 50e6);

    vm.warp(deadline);
    vm.prank(oracle);
    market.resolve(true);

    vm.prank(bob);
    vm.expectRevert(PredictionMarket.NothingToRedeem.selector);
    market.redeem();
}

function test_RevertWhen_ResolveBeforeDeadline() public {
    vm.prank(oracle);
    vm.expectRevert(PredictionMarket.DeadlineNotReached.selector);
    market.resolve(true);
}

function test_RevertWhen_NonOracleResolves() public {
    vm.warp(deadline);
    vm.prank(alice);
    vm.expectRevert(PredictionMarket.NotOracle.selector);
    market.resolve(true);
}

function test_LpCanRemoveAfterResolveThenRedeem() public {
    _seedPool(alice, 100e6, 100e6);
    vm.warp(deadline);
    vm.prank(oracle);
    market.resolve(true);

    uint256 lp = market.lpBalances(alice);
    vm.prank(alice);
    market.removeLiquidity(lp, 0, 0);

    vm.prank(alice);
    market.redeem();
    assertGt(usdc.balanceOf(alice), 0);
}
```

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement resolve + redeem**

- [ ] **Step 4: Run all PredictionMarket tests — pass**

- [ ] **Step 5: Commit**

```bash
git add src/prediction/PredictionMarket.sol test/prediction/PredictionMarket.t.sol
git commit -m "feat(prediction): add oracle resolve and winner redeem"
```

---

### Task 6: PredictionMarketFactory

**Files:**
- Create: `src/prediction/PredictionMarketFactory.sol`
- Create: `test/prediction/PredictionMarketFactory.t.sol`

**Interfaces:**
- Consumes: `PredictionMarket`
- Produces:
  - `function createMarket(string calldata question, address collateral, uint256 deadline, address oracle) external returns (address market)`
  - `function marketCount() external view returns (uint256)`
  - `function markets(uint256 index) external view returns (address)`
  - event `MarketCreated(address indexed market, address indexed creator, address collateral, uint256 deadline, address oracle, string question)`
  - `oracle == address(0)` → `oracle = msg.sender`

- [ ] **Step 1: Write failing factory tests**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PredictionMarketFactory} from "../../src/prediction/PredictionMarketFactory.sol";
import {PredictionMarket} from "../../src/prediction/PredictionMarket.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}
    function decimals() public pure override returns (uint8) { return 6; }
}

contract PredictionMarketFactoryTest is Test {
    PredictionMarketFactory internal factory;
    MockUSDC internal usdc;
    address internal alice = makeAddr("alice");

    function setUp() public {
        factory = new PredictionMarketFactory();
        usdc = new MockUSDC();
    }

    function test_CreateMarketRegistersAndDefaultsOracle() public {
        uint256 marketDeadline = block.timestamp + 3 days;
        vm.prank(alice);
        address m = factory.createMarket("Q?", address(usdc), marketDeadline, address(0));

        assertEq(factory.marketCount(), 1);
        assertEq(factory.markets(0), m);
        assertEq(PredictionMarket(m).oracle(), alice);
        assertEq(PredictionMarket(m).deadline(), marketDeadline);
    }
}
```

- [ ] **Step 2: Run — expect fail**

Run: `forge test --match-path test/prediction/PredictionMarketFactory.t.sol -vv`

- [ ] **Step 3: Implement factory**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PredictionMarket} from "./PredictionMarket.sol";

/// @notice 无许可创建二元预测市场。
contract PredictionMarketFactory {
    address[] public markets;

    event MarketCreated(
        address indexed market,
        address indexed creator,
        address collateral,
        uint256 deadline,
        address oracle,
        string question
    );

    function marketCount() external view returns (uint256) {
        return markets.length;
    }

    /// @notice 创建市场；`oracle` 为 0 时使用调用者。
    function createMarket(
        string calldata question,
        address collateral,
        uint256 deadline,
        address oracle
    ) external returns (address market) {
        if (oracle == address(0)) oracle = msg.sender;
        PredictionMarket m = new PredictionMarket(question, collateral, deadline, oracle);
        market = address(m);
        markets.push(market);
        emit MarketCreated(market, msg.sender, collateral, deadline, oracle, question);
    }
}
```

- [ ] **Step 4: Run factory + market tests — pass**

Run: `forge test --match-path test/prediction/ -vv`

- [ ] **Step 5: Commit**

```bash
git add src/prediction/PredictionMarketFactory.sol test/prediction/PredictionMarketFactory.t.sol
git commit -m "feat(prediction): add PredictionMarketFactory"
```

---

### Task 7: Fuzz 与边界补全

**Files:**
- Modify: `test/prediction/PredictionMarket.t.sol`

**Interfaces:** 无新生产接口；覆盖 spec 测试计划剩余项。

- [ ] **Step 1: Add fuzz + remaining edge tests**

```solidity
function testFuzz_SplitMergeRoundtrip(uint256 amount) public {
    amount = bound(amount, 1, 100_000e6);
    usdc.mint(alice, amount);
    vm.startPrank(alice);
    usdc.approve(address(market), amount);
    uint256 colBefore = usdc.balanceOf(alice);
    market.split(amount);
    market.merge(amount);
    vm.stopPrank();
    assertEq(usdc.balanceOf(alice), colBefore);
    assertEq(market.yesToken().balanceOf(alice), 0);
}

function testFuzz_SwapKNeverDecreases(uint256 amountIn) public {
    _seedPool(alice, 1_000e6, 1_000e6);
    amountIn = bound(amountIn, 1e6, 100e6);
    address bob = makeAddr("bob");
    _split(bob, amountIn);
    uint256 kBefore = market.yesReserve() * market.noReserve();
    vm.startPrank(bob);
    market.yesToken().approve(address(market), amountIn);
    market.swapYesForNo(amountIn, 0);
    vm.stopPrank();
    assertGe(market.yesReserve() * market.noReserve(), kBefore);
}

function test_RevertWhen_DoubleResolve() public {
    vm.warp(deadline);
    vm.prank(oracle);
    market.resolve(false);
    vm.prank(oracle);
    vm.expectRevert(PredictionMarket.AlreadyResolved.selector);
    market.resolve(false);
}

function test_RedeemNoWins() public {
    _split(alice, 80e6);
    vm.warp(deadline);
    vm.prank(oracle);
    market.resolve(false);
    uint256 before = usdc.balanceOf(alice);
    vm.prank(alice);
    market.redeem();
    assertEq(usdc.balanceOf(alice), before + 80e6);
    assertEq(market.noToken().balanceOf(alice), 0);
}
```

- [ ] **Step 2: Run**

Run: `forge test --match-path test/prediction/ -vv`

Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/prediction/PredictionMarket.t.sol
git commit -m "test(prediction): add fuzz and resolve edge cases"
```

---

### Task 8: 部署脚本

**Files:**
- Create: `script/prediction/DeployPredictionMarket.s.sol`

**Interfaces:**
- Consumes: `BaseScript`、`PredictionMarketFactory`、`PredictionMarket`
- Produces: 可 `--broadcast` 的 `DeployPredictionMarket` script

环境变量：

- `COLLATERAL` 未设 → 部署 6 decimals MockUSDC 并 mint 给 deployer
- `QUESTION` 默认 `"Demo: ETH above 5000 by deadline?"`
- `DEADLINE` 默认 `block.timestamp + 7 days`
- `ORACLE` 默认 deployer

- [ ] **Step 1: Write deploy script**

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {PredictionMarketFactory} from "../../src/prediction/PredictionMarketFactory.sol";
import {PredictionMarket} from "../../src/prediction/PredictionMarket.sol";

contract DeployMockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1_000_000_000e6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
}

contract DeployPredictionMarket is BaseScript {
    function run() public broadcaster {
        address collateral = vm.envOr("COLLATERAL", address(0));
        if (collateral == address(0)) {
            DeployMockUSDC mock = new DeployMockUSDC();
            collateral = address(mock);
            saveContract("MockUSDC", collateral);
            console.log("MockUSDC: ", collateral);
        }

        PredictionMarketFactory factory = new PredictionMarketFactory();
        saveContract("PredictionMarketFactory", address(factory));

        string memory question = vm.envOr("QUESTION", string("Demo: ETH above 5000 by deadline?"));
        uint256 marketDeadline = vm.envOr("DEADLINE", uint256(block.timestamp + 7 days));
        address oracleAddr = vm.envOr("ORACLE", deployer);

        address marketAddr = factory.createMarket(question, collateral, marketDeadline, oracleAddr);
        PredictionMarket m = PredictionMarket(marketAddr);

        saveContract("PredictionMarket", marketAddr);
        saveContract("YesToken", address(m.yesToken()));
        saveContract("NoToken", address(m.noToken()));

        console.log("Factory: ", address(factory));
        console.log("Market:  ", marketAddr);
        console.log("YES:     ", address(m.yesToken()));
        console.log("NO:      ", address(m.noToken()));
        console.log("deadline:", marketDeadline);
    }
}
```

- [ ] **Step 2: Compile script**

Run: `forge build`

Expected: 编译成功

- [ ] **Step 3: Commit**

```bash
git add script/prediction/DeployPredictionMarket.s.sol
git commit -m "feat(prediction): add deploy script for factory and demo market"
```

---

## Spec Coverage Checklist

| Spec 项 | Task |
|---|---|
| OutcomeToken mint/burn + decimals | 1 |
| split / merge | 2 |
| add/removeLiquidity + MINIMUM_LIQUIDITY | 3 |
| CPAMM swap 0.3% + getYesPrice | 4 |
| resolve / redeem + LP after resolve | 5 |
| Factory createMarket + 登记 | 6 |
| fuzz k / roundtrip / 边界 | 7 |
| Deploy script + MockUSDC | 8 |
| 无前端 / 无 CTF / 无协议费抽成 | 全局约束（不实现） |

## Self-Review Notes

- 无 TBD/占位步骤；函数名与 spec 一致（`getYesPrice`、`swapYesForNo`、`FEE_BPS = 30`）。
- TradingClosed 禁止 `removeLiquidity`，Resolved 允许——Task 3 helpers 与 Task 5 测试共同锁定。
- `InvalidLiquidityRatio` 用于后续 LP 计算出 0 的情况。
- OpenZeppelin 导入路径与 Global Constraints 一致。
