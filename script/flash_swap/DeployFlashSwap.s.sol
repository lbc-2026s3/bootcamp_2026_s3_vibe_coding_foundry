// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// 示例运行日志解读（数量均为 18 位小数 wei；÷1e18 即代币个数）
// ---------------------------------------------------------------------------
// MyToken1 / MyToken2            — 两个演示 ERC20 地址
// FactoryA / PoolA               — 借入侧 Factory 与池；初始价 1 MT1 = 2 MT2
// FactoryB / PoolB               — 卖出侧 Factory 与池；初始价 1 MT1 = 1 MT2
// FlashSwapArbitrage             — 闪电套利合约（利润打给 deployer）
//
// BEFORE：deployer 余下未注入流动性的代币；PoolA 100k/200k，PoolB 100k/100k
//   spot MT2/MT1                 — 即期价（未计手续费），A≈2e18、B≈1e18 即价差来源
// Executing flashSwap            — 从 PoolA 借 100 MT2，在 PoolB 换成 MT1 后还给 PoolA
// AFTER：两池储备与即期价被套利拉近
// PROFIT：
//   deployer MT1 delta > 0       — 套利净利润（约 49.43 MT1）
//   PoolA MT2 delta = -100e18    — 借出的 MT2；PoolA MT1 delta > 0 为还款（含手续费）
//   PoolB MT2 增加 / MT1 减少    — 在便宜池卖掉借来的 MT2 换 MT1
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {MyToken1} from "../../src/flash_swap/MyToken1.sol";
import {MyToken2} from "../../src/flash_swap/MyToken2.sol";
import {FlashSwapArbitrage} from "../../src/flash_swap/FlashSwapArbitrage.sol";
import {UniswapV2Factory} from "uniswapv2/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "uniswapv2/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Library} from "uniswapv2/libraries/UniswapV2Library.sol";

/// @notice 部署双 Factory 价差池 + FlashSwapArbitrage，并执行一次套利、打印前后状态。
/// @dev PoolA: 1 MyToken1 = 2 MyToken2；PoolB: 1 MyToken1 = 1 MyToken2。
/// @dev forge script script/flash_swap/DeployFlashSwap.s.sol:DeployFlashSwap \
///        --broadcast --rpc-url local \
///        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
///        && cat ./deployments/LATEST.txt
contract DeployFlashSwap is BaseScript {
    uint256 public constant POOL_A_MT1 = 100_000e18;
    uint256 public constant POOL_A_MT2 = 200_000e18;
    uint256 public constant POOL_B_MT1 = 100_000e18;
    uint256 public constant POOL_B_MT2 = 100_000e18;
    /// @dev 从 PoolA 闪电借入的 MT2 数量
    uint256 public constant BORROW_MT2 = 100e18;

    MyToken1 public token1;
    MyToken2 public token2;
    UniswapV2Factory public factoryA;
    UniswapV2Factory public factoryB;
    address public poolA;
    address public poolB;
    FlashSwapArbitrage public flashSwap;

    function run() public broadcaster {
        token1 = new MyToken1();
        token2 = new MyToken2();
        saveContract("MyToken1", address(token1));
        saveContract("MyToken2", address(token2));

        factoryA = new UniswapV2Factory(deployer);
        factoryB = new UniswapV2Factory(deployer);
        saveContract("UniswapV2FactoryA", address(factoryA));
        saveContract("UniswapV2FactoryB", address(factoryB));

        // PoolA: 1 MT1 = 2 MT2
        poolA = _seedPool(factoryA, POOL_A_MT1, POOL_A_MT2);
        saveContract("PoolA", poolA);

        // PoolB: 1 MT1 = 1 MT2
        poolB = _seedPool(factoryB, POOL_B_MT1, POOL_B_MT2);
        saveContract("PoolB", poolB);

        // 从 PoolA 借入，在 FactoryB（PoolB）卖出
        flashSwap = new FlashSwapArbitrage(address(factoryA), address(factoryB), deployer);
        saveContract("FlashSwapArbitrage", address(flashSwap));

        console.log("===== deployed addresses =====");
        console.log("MyToken1 (MT1):     ", address(token1));
        console.log("MyToken2 (MT2):     ", address(token2));
        console.log("FactoryA (borrow):  ", address(factoryA));
        console.log("PoolA (1 MT1=2 MT2):", poolA);
        console.log("FactoryB (sell):    ", address(factoryB));
        console.log("PoolB (1 MT1=1 MT2):", poolB);
        console.log("FlashSwapArbitrage: ", address(flashSwap));
        console.log("(profitReceiver = deployer)");

        // --- 套利前状态 ---
        console.log("");
        console.log("========== BEFORE ARBITRAGE ==========");
        console.log(unicode"(deployer 余额 = 未注入池子的剩余代币；池储备按 MT1/MT2 顺序)");
        (uint256 mt1Before, uint256 mt2Before, uint256 a1Before, uint256 a2Before, uint256 b1Before, uint256 b2Before) =
            _snapshot("before");

        // 从 PoolA 借 MT2，在 PoolB 换成 MT1 还款，利润给 deployer
        console.log("");
        console.log("===== executing flashSwap =====");
        console.log("borrow MT2 from PoolA, amount (wei):", BORROW_MT2);
        console.log("then sell MT2 for MT1 on PoolB, repay MT1 to PoolA, keep surplus MT1");
        flashSwap.flashSwap(poolA, address(token2), BORROW_MT2);

        // --- 套利后状态 ---
        console.log("");
        console.log("========== AFTER ARBITRAGE ==========");
        console.log(unicode"(两池价差被部分抹平；spot 应比 before 更接近)");
        (uint256 mt1After, uint256 mt2After, uint256 a1After, uint256 a2After, uint256 b1After, uint256 b2After) =
            _snapshot("after");

        console.log("");
        console.log("========== PROFIT / DELTAS ==========");
        console.log("deployer MT1 profit (wei):", mt1After - mt1Before); // 套利净利润
        console.log("deployer MT2 delta (wei): ", int256(mt2After) - int256(mt2Before)); // 应为 0
        console.log("PoolA MT1 delta (repay+fee):", int256(a1After) - int256(a1Before)); // 收到的还款 MT1
        console.log("PoolA MT2 delta (borrowed): ", int256(a2After) - int256(a2Before)); // 借出的 MT2，约 -BORROW
        console.log("PoolB MT1 delta (sold for): ", int256(b1After) - int256(b1Before)); // 换出的 MT1
        console.log("PoolB MT2 delta (sold into):", int256(b2After) - int256(b2Before)); // 换入的 MT2
    }

    function _seedPool(UniswapV2Factory factory, uint256 amount1, uint256 amount2)
        internal
        returns (address pair)
    {
        pair = factory.createPair(address(token1), address(token2));
        token1.transfer(pair, amount1);
        token2.transfer(pair, amount2);
        IUniswapV2Pair(pair).mint(deployer);
    }

    /// @notice 打印并返回 deployer 余额 + 两池储备（按 MT1/MT2 顺序）
    function _snapshot(string memory label)
        internal
        view
        returns (
            uint256 deployerMt1,
            uint256 deployerMt2,
            uint256 poolAMt1,
            uint256 poolAMt2,
            uint256 poolBMt1,
            uint256 poolBMt2
        )
    {
        deployerMt1 = token1.balanceOf(deployer);
        deployerMt2 = token2.balanceOf(deployer);
        (poolAMt1, poolAMt2) =
            UniswapV2Library.getReserves(address(factoryA), address(token1), address(token2));
        (poolBMt1, poolBMt2) =
            UniswapV2Library.getReserves(address(factoryB), address(token1), address(token2));

        console.log("--- snapshot:", label, "---");
        console.log("deployer MT1 balance (wei):", deployerMt1);
        console.log("deployer MT2 balance (wei):", deployerMt2);
        console.log("PoolA reserve MT1 (wei):   ", poolAMt1);
        console.log("PoolA reserve MT2 (wei):   ", poolAMt2);
        console.log("PoolB reserve MT1 (wei):   ", poolBMt1);
        console.log("PoolB reserve MT2 (wei):   ", poolBMt2);
        // 即期价：1 MT1 可换多少 MT2（未计手续费）；单位 1e18 = 1.0
        if (poolAMt1 > 0) {
            console.log("PoolA spot MT2 per MT1 (1e18=1.0):", (poolAMt2 * 1e18) / poolAMt1);
        }
        if (poolBMt1 > 0) {
            console.log("PoolB spot MT2 per MT1 (1e18=1.0):", (poolBMt2 * 1e18) / poolBMt1);
        }
    }
}
