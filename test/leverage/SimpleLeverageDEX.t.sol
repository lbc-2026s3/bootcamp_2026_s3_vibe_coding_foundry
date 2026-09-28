// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../src/lending/MockERC20.sol";
import {SimpleLeverageDEX} from "../../src/leverage/SimpleLeverageDEX.sol";

contract SimpleLeverageDEXTest is Test {
    // 较深虚拟流动性，方便测试大仓位推价；初始价 1 ETH = 1000 USDC
    uint256 internal constant V_ETH = 1_000 ether;
    uint256 internal constant V_USDC = 1_000_000e18;

    MockERC20 internal usdc;
    SimpleLeverageDEX internal dex;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal liquidator = makeAddr("liquidator");

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC");
        dex = new SimpleLeverageDEX(V_ETH, V_USDC, address(usdc));

        usdc.mint(alice, 1_000_000e18);
        usdc.mint(bob, 1_000_000e18);
        usdc.mint(liquidator, 1_000_000e18);
    }

    function _approveAndOpen(address user, uint256 margin, uint256 level, bool long) internal {
        vm.startPrank(user);
        usdc.approve(address(dex), margin);
        dex.openPosition(margin, level, long);
        vm.stopPrank();
    }

    function _equity(uint256 margin, int256 pnl) internal pure returns (uint256) {
        if (pnl >= 0) return margin + uint256(pnl);
        uint256 loss = uint256(-pnl);
        if (loss >= margin) return 0;
        return margin - loss;
    }

    function test_ConstructorSetsReservesAndUSDC() public view {
        assertEq(dex.vETHAmount(), V_ETH);
        assertEq(dex.vUSDCAmount(), V_USDC);
        assertEq(dex.vK(), V_ETH * V_USDC);
        assertEq(address(dex.USDC()), address(usdc));
    }

    function test_RevertWhen_ConstructorZeroUSDC() public {
        vm.expectRevert("zero usdc");
        new SimpleLeverageDEX(V_ETH, V_USDC, address(0));
    }

    function test_OpenLongRecordsPositionAndPullsMargin() public {
        uint256 margin = 1_000e18;
        uint256 level = 5;

        _approveAndOpen(alice, margin, level, true);

        (uint256 m, uint256 borrowed, int256 pos) = dex.positions(alice);
        assertEq(m, margin);
        assertEq(borrowed, margin * (level - 1));
        assertGt(pos, 0);
        assertEq(usdc.balanceOf(address(dex)), margin);
        assertEq(usdc.balanceOf(alice), 1_000_000e18 - margin);
        assertGt(dex.vUSDCAmount(), V_USDC);
        assertLt(dex.vETHAmount(), V_ETH);
    }

    function test_OpenShortRecordsNegativePosition() public {
        _approveAndOpen(alice, 1_000e18, 3, false);

        (,, int256 pos) = dex.positions(alice);
        assertLt(pos, 0);
        assertLt(dex.vUSDCAmount(), V_USDC);
        assertGt(dex.vETHAmount(), V_ETH);
    }

    function test_RevertWhen_OpenTwice() public {
        _approveAndOpen(alice, 1_000e18, 2, true);

        vm.startPrank(alice);
        usdc.approve(address(dex), 1_000e18);
        vm.expectRevert("Position already open");
        dex.openPosition(1_000e18, 2, true);
        vm.stopPrank();
    }

    function test_RevertWhen_InvalidLeverageOrZeroMargin() public {
        vm.startPrank(alice);
        usdc.approve(address(dex), type(uint256).max);

        vm.expectRevert("zero margin");
        dex.openPosition(0, 2, true);

        vm.expectRevert("invalid leverage");
        dex.openPosition(100e18, 1, true);

        vm.expectRevert("invalid leverage");
        dex.openPosition(100e18, 11, true);
        vm.stopPrank();
    }

    function test_CloseLongRoundtripNearBreakeven() public {
        uint256 margin = 1_000e18;
        _approveAndOpen(alice, margin, 2, true);

        uint256 balBefore = usdc.balanceOf(alice);
        int256 pnl = dex.calculatePnL(alice);

        vm.prank(alice);
        dex.closePosition();

        (,, int256 pos) = dex.positions(alice);
        assertEq(pos, 0);
        assertEq(usdc.balanceOf(alice), balBefore + _equity(margin, pnl));
    }

    function test_LongProfitsWhenPriceRises() public {
        _approveAndOpen(alice, 500e18, 2, true);
        int256 pnlBeforeBob = dex.calculatePnL(alice);

        _approveAndOpen(bob, 50_000e18, 5, true);

        int256 pnlAfter = dex.calculatePnL(alice);
        // bob 跟着做多 eth 会推高价格，所以 alice 的多仓赚钱了
        assertGt(pnlAfter, pnlBeforeBob);
        assertGt(pnlAfter, 0);

        uint256 balBefore = usdc.balanceOf(alice);
        (uint256 margin,,) = dex.positions(alice);

        vm.prank(alice);
        dex.closePosition();

        assertEq(usdc.balanceOf(alice), balBefore + margin + uint256(pnlAfter));
    }

    function test_ShortProfitsWhenPriceFalls() public {
        // alice 先做空；bob 再大仓做空，继续压低 eth 价格，alice 空仓应盈利
        _approveAndOpen(alice, 500e18, 2, false);
        _approveAndOpen(bob, 50_000e18, 5, false);

        int256 pnl = dex.calculatePnL(alice);
        // bob 做空推低价格后，alice 空仓赚钱了
        assertGt(pnl, 0);

        uint256 balBefore = usdc.balanceOf(alice);
        (uint256 margin,,) = dex.positions(alice);

        vm.prank(alice);
        dex.closePosition();

        // 平仓拿到：保证金 + 盈利
        assertEq(usdc.balanceOf(alice), balBefore + margin + uint256(pnl));
    }

    function test_LongLosesWhenPriceFalls() public {
        _approveAndOpen(alice, 1_000e18, 5, true);
        _approveAndOpen(bob, 80_000e18, 5, false);

        int256 pnl = dex.calculatePnL(alice);
        assertLt(pnl, 0);

        uint256 balBefore = usdc.balanceOf(alice);
        (uint256 margin,,) = dex.positions(alice);

        vm.prank(alice);
        dex.closePosition();

        assertEq(usdc.balanceOf(alice), balBefore + _equity(margin, pnl));
    }

    function test_RevertWhen_CloseWithoutPosition() public {
        vm.prank(alice);
        vm.expectRevert("No open position");
        dex.closePosition();
    }

    function test_LiquidateLongWhenLossExceeds80PercentMargin() public {
        _approveAndOpen(alice, 1_000e18, 10, true);
        // 名义约 400k，压低价格使 10x 多仓亏损 > 80% 保证金
        _approveAndOpen(bob, 40_000e18, 10, false);

        int256 pnl = dex.calculatePnL(alice);
        (uint256 margin,,) = dex.positions(alice);
        assertLt(pnl, -int256(margin * 8 / 10));

        uint256 liqBalBefore = usdc.balanceOf(liquidator);
        uint256 aliceBalBefore = usdc.balanceOf(alice);
        uint256 equity = _equity(margin, pnl);
        uint256 expectedReward = margin * 5 / 100;
        if (expectedReward > equity) expectedReward = equity;
        uint256 expectedUser = equity - expectedReward;

        vm.prank(liquidator);
        dex.liquidatePosition(alice);

        (,, int256 pos) = dex.positions(alice);
        assertEq(pos, 0);
        assertEq(usdc.balanceOf(liquidator), liqBalBefore + expectedReward);
        assertEq(usdc.balanceOf(alice), aliceBalBefore + expectedUser);
    }

    function test_RevertWhen_LiquidateHealthyPosition() public {
        _approveAndOpen(alice, 1_000e18, 2, true);

        vm.prank(liquidator);
        vm.expectRevert("Position not liquidatable");
        dex.liquidatePosition(alice);
    }

    function test_RevertWhen_LiquidateSelf() public {
        _approveAndOpen(alice, 1_000e18, 10, true);
        _approveAndOpen(bob, 40_000e18, 10, false);

        vm.prank(alice);
        vm.expectRevert("Cannot liquidate own position");
        dex.liquidatePosition(alice);
    }

    function test_CloseWhenLossExceedsMarginPaysZero() public {
        // alice 10x 做多；bob 超大空单砸盘，把 alice 打到穿仓（亏损 >= 全部保证金）
        _approveAndOpen(alice, 500e18, 10, true);
        _approveAndOpen(bob, 90_000e18, 10, false);

        int256 pnl = dex.calculatePnL(alice);
        (uint256 margin,,) = dex.positions(alice);
        // 穿仓：未实现亏损至少吃光保证金
        assertTrue(pnl <= -int256(margin));

        uint256 balBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        dex.closePosition();

        // 净值按 0 结算：不退 USDC，仓位清空
        assertEq(usdc.balanceOf(alice), balBefore);
        (,, int256 pos) = dex.positions(alice);
        assertEq(pos, 0);
    }

    function test_ShortLosesWhenPriceRises() public {
        _approveAndOpen(alice, 1_000e18, 5, false);
        _approveAndOpen(bob, 80_000e18, 5, true);

        int256 pnl = dex.calculatePnL(alice);
        assertLt(pnl, 0);

        uint256 balBefore = usdc.balanceOf(alice);
        (uint256 margin,,) = dex.positions(alice);

        vm.prank(alice);
        dex.closePosition();

        assertEq(usdc.balanceOf(alice), balBefore + _equity(margin, pnl));
        assertEq(dex.totalShortEth(), 0);
    }

    function test_LiquidateShortWhenLossExceeds80PercentMargin() public {
        _approveAndOpen(alice, 1_000e18, 10, false);
        _approveAndOpen(bob, 40_000e18, 10, true);

        int256 pnl = dex.calculatePnL(alice);
        (uint256 margin,,) = dex.positions(alice);
        assertLt(pnl, -int256(margin * 8 / 10));

        uint256 liqBalBefore = usdc.balanceOf(liquidator);
        uint256 aliceBalBefore = usdc.balanceOf(alice);
        uint256 equity = _equity(margin, pnl);
        uint256 expectedReward = margin * 5 / 100;
        if (expectedReward > equity) expectedReward = equity;
        uint256 expectedUser = equity - expectedReward;

        vm.prank(liquidator);
        dex.liquidatePosition(alice);

        (,, int256 pos) = dex.positions(alice);
        assertEq(pos, 0);
        assertEq(dex.totalShortEth(), 0);
        assertEq(usdc.balanceOf(liquidator), liqBalBefore + expectedReward);
        assertEq(usdc.balanceOf(alice), aliceBalBefore + expectedUser);
    }

    function test_RevertWhen_LongWouldTrapExistingShorts() public {
        // 空头名义 500k → totalShortEth ≈ 1000 ETH（初始池 1000 ETH / 1M USDC）
        _approveAndOpen(alice, 50_000e18, 10, false);

        vm.startPrank(bob);
        usdc.approve(address(dex), 100_000e18);
        // 做多名义 1M 会把 vETH 压到 < totalShortEth
        vm.expectRevert("insufficient liquidity");
        dex.openPosition(100_000e18, 10, true);
        vm.stopPrank();

        vm.prank(alice);
        dex.closePosition();
        assertEq(dex.totalShortEth(), 0);
    }

    function test_CloseShortRoundtripNearBreakeven() public {
        uint256 margin = 1_000e18;
        _approveAndOpen(alice, margin, 2, false);

        uint256 balBefore = usdc.balanceOf(alice);
        int256 pnl = dex.calculatePnL(alice);

        vm.prank(alice);
        dex.closePosition();

        (,, int256 pos) = dex.positions(alice);
        assertEq(pos, 0);
        assertEq(dex.totalShortEth(), 0);
        assertEq(usdc.balanceOf(alice), balBefore + _equity(margin, pnl));
    }

    function testFuzz_OpenCloseLongPreservesUserFundsWithinPool(uint256 margin, uint256 level) public {
        margin = bound(margin, 1e18, 5_000e18);
        level = bound(level, 2, 5);

        uint256 aliceBefore = usdc.balanceOf(alice);
        _approveAndOpen(alice, margin, level, true);

        int256 pnl = dex.calculatePnL(alice);
        vm.prank(alice);
        dex.closePosition();

        uint256 aliceAfter = usdc.balanceOf(alice);
        assertLe(aliceAfter, aliceBefore);
        assertEq(aliceAfter, aliceBefore - margin + _equity(margin, pnl));
    }
}
