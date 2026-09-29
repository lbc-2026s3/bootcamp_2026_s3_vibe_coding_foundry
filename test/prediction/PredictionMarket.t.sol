// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PredictionMarket} from "../../src/prediction/PredictionMarket.sol";
import {OutcomeToken} from "../../src/prediction/OutcomeToken.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
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
        OutcomeToken yes = market.yesToken();
        vm.prank(bob);
        yes.transfer(alice, 50e6);

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
}
