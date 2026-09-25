// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MyToken1} from "../../src/flash_swap/MyToken1.sol";
import {MyToken2} from "../../src/flash_swap/MyToken2.sol";
import {PoolATwapOracle} from "../../src/flash_swap/PoolATwapOracle.sol";
import {UniswapV2Factory} from "uniswapv2/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "uniswapv2/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Library} from "uniswapv2/libraries/UniswapV2Library.sol";

/// @notice PoolA TWAP：在不同时间点模拟多笔交易，再读时间加权均价
contract PoolATwapOracleTest is Test {
    address public owner = makeAddr("owner");
    address public trader = makeAddr("trader");

    MyToken1 public token1;
    MyToken2 public token2;
    UniswapV2Factory public factoryA;
    address public poolA;
    PoolATwapOracle public oracle;

    uint256 constant LIQ_MT1 = 100_000e18;
    uint256 constant LIQ_MT2 = 200_000e18; // 初始 1 MT1 = 2 MT2（若 token0=MT1）
    uint32 constant PERIOD = 1 hours;

    function setUp() public {
        vm.startPrank(owner);
        token1 = new MyToken1();
        token2 = new MyToken2();
        factoryA = new UniswapV2Factory(owner);

        poolA = factoryA.createPair(address(token1), address(token2));
        token1.transfer(poolA, LIQ_MT1);
        token2.transfer(poolA, LIQ_MT2);
        IUniswapV2Pair(poolA).mint(owner);

        oracle = new PoolATwapOracle(poolA, PERIOD);

        // 给 trader 换币用的余额
        token1.transfer(trader, 50_000e18);
        token2.transfer(trader, 50_000e18);
        vm.stopPrank();
    }

    /// @dev 在 PoolA 上做一笔单向 swap（直接转币 + pair.swap）
    function _swap(address tokenIn, uint256 amountIn) internal {
        address tokenOut = tokenIn == address(token1) ? address(token2) : address(token1);
        (uint256 reserveIn, uint256 reserveOut) =
            UniswapV2Library.getReserves(address(factoryA), tokenIn, tokenOut);
        uint256 amountOut = UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);

        vm.startPrank(trader);
        IERC20Like(tokenIn).transfer(poolA, amountIn);
        (address t0,) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
        (uint256 amount0Out, uint256 amount1Out) =
            tokenIn == t0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
        IUniswapV2Pair(poolA).swap(amount0Out, amount1Out, trader, new bytes(0));
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateBeforePeriod() public {
        vm.expectRevert("PERIOD_NOT_ELAPSED");
        oracle.update();
    }

    function test_TwapNearInitialPrice_AfterIdlePeriod() public {
        // 窗口内无交易，仅时间流逝 → TWAP ≈ 初始现货
        uint256 spotBefore = oracle.spotPrice1Per0();
        vm.warp(block.timestamp + PERIOD);
        // 触发 pair 累加器写盘（可选；oracle 也有反事实补齐）
        IUniswapV2Pair(poolA).sync();

        oracle.update();

        uint256 twap = oracle.twapPrice1Per0();
        // 允许 0.1% 误差（定点截断）
        assertApproxEqRel(twap, spotBefore, 0.001e18);

        // consult：1 token0 → 约 spot 个 token1
        uint256 out = oracle.consult(oracle.token0(), 1e18);
        assertApproxEqRel(out, spotBefore, 0.001e18);
    }

    function test_TwapWithTradesAtDifferentTimes() public {
        // 记录初始现货（token1/token0，1e18）
        uint256 initialSpot = oracle.spotPrice1Per0();
        console.log("t0 initial spot token1/token0:", initialSpot);

        // --- t1: +20min，用 MT1 买 MT2 ---
        vm.warp(block.timestamp + 20 minutes);
        _swap(address(token1), 5_000e18);
        uint256 spotAfterTrade1 = oracle.spotPrice1Per0();
        console.log("t1 +20m after sell MT1 spot:", spotAfterTrade1);

        // --- t2: +40min 总经过，反向用 MT2 买 MT1 ---
        vm.warp(block.timestamp + 20 minutes);
        _swap(address(token2), 8_000e18);
        uint256 spotAfterTrade2 = oracle.spotPrice1Per0();
        console.log("t2 +40m after sell MT2 spot:", spotAfterTrade2);

        // --- t3: +70min，再一笔大卖压 ---
        vm.warp(block.timestamp + 30 minutes);
        _swap(address(token1), 10_000e18);
        uint256 finalSpot = oracle.spotPrice1Per0();
        console.log("t3 +70m after big sell MT1 spot:", finalSpot);

        // 再等到满 PERIOD（从构造起至少 1h；当前已 ~70m，再补 30m）
        vm.warp(block.timestamp + 30 minutes);
        assertGe(block.timestamp - oracle.blockTimestampLast(), PERIOD);

        oracle.update();

        uint256 twap = oracle.twapPrice1Per0();
        console.log("TWAP token1/token0:", twap);
        console.log("final spot:        ", finalSpot);

        // TWAP 是时间加权：应介于窗口内出现过的价格区间
        uint256 minP = initialSpot;
        uint256 maxP = initialSpot;
        if (spotAfterTrade1 < minP) minP = spotAfterTrade1;
        if (spotAfterTrade1 > maxP) maxP = spotAfterTrade1;
        if (spotAfterTrade2 < minP) minP = spotAfterTrade2;
        if (spotAfterTrade2 > maxP) maxP = spotAfterTrade2;
        if (finalSpot < minP) minP = finalSpot;
        if (finalSpot > maxP) maxP = finalSpot;

        assertGe(twap, minP - minP / 1000);
        assertLe(twap, maxP + maxP / 1000);

        // 有交易扰动后，终价通常偏离 TWAP
        assertTrue(finalSpot != twap || initialSpot == finalSpot, "expect TWAP != final spot when price moved");

        // consult 与 twapPrice1Per0 一致
        uint256 consultOut = oracle.consult(oracle.token0(), 1e18);
        assertEq(consultOut, twap);
    }

    function test_MultipleUpdateWindows() public {
        // 第一窗：空闲
        vm.warp(block.timestamp + PERIOD);
        oracle.update();
        uint256 twap1 = oracle.twapPrice1Per0();

        // 第二窗：中间猛拉价格
        vm.warp(block.timestamp + 10 minutes);
        _swap(address(token1), 20_000e18);
        vm.warp(block.timestamp + PERIOD);
        oracle.update();
        uint256 twap2 = oracle.twapPrice1Per0();

        console.log("window1 TWAP:", twap1);
        console.log("window2 TWAP:", twap2);
        // 卖 MT1：若 MT1==token0，则 r1/r0 下降；若 MT1==token1，则 r1/r0 上升
        if (oracle.token0() == address(token1)) {
            assertLt(twap2, twap1);
        } else {
            assertGt(twap2, twap1);
        }
    }
}

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
}
