// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {UniswapV2Factory} from "../../uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../../uniswapv2/UniswapV2Router02.sol";
import {UniswapV2Pair} from "../../uniswapv2/UniswapV2Pair.sol";
import {IUniswapV2Pair} from "../../uniswapv2/interfaces/IUniswapV2Pair.sol";
import {WETH9} from "../../uniswapv2/WETH9.sol";
import {MyTokenV1} from "../../src/MyTokenV1.sol";

/// @notice UniswapV2Router02 核心路径:加池 / 兑换 / 撤池 / 截止时间
contract UniswapV2Router02Test is Test {
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    WETH9 public weth;
    MyTokenV1 public tokenA;
    MyTokenV1 public tokenB;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant LIQ_A = 100_000e18;
    uint256 constant LIQ_B = 100_000e18;

    function setUp() public {
        vm.startPrank(owner);
        weth = new WETH9();
        factory = new UniswapV2Factory(owner);
        router = new UniswapV2Router02(address(factory), address(weth));
        tokenA = new MyTokenV1();
        tokenB = new MyTokenV1();
        vm.stopPrank();
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _seedAndApprove(address user, uint256 amountA, uint256 amountB) internal {
        vm.startPrank(owner);
        tokenA.transfer(user, amountA);
        tokenB.transfer(user, amountB);
        vm.stopPrank();

        vm.startPrank(user);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function _addDefaultLiquidity(address lp) internal returns (uint256 liquidity) {
        _seedAndApprove(lp, LIQ_A, LIQ_B);
        vm.prank(lp);
        (,, liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQ_A,
            LIQ_B,
            0,
            0,
            lp,
            _deadline()
        );
    }

    function test_Constructor_SetsFactoryAndWETH() public view {
        assertEq(router.factory(), address(factory));
        assertEq(router.WETH(), address(weth));
    }

    function test_AddLiquidity_CreatesPairAndMintsLP() public {
        uint256 liquidity = _addDefaultLiquidity(alice);

        address pair = factory.getPair(address(tokenA), address(tokenB));
        assertTrue(pair != address(0), "pair not created");
        assertEq(factory.allPairsLength(), 1);
        assertGt(liquidity, 0);
        assertEq(IUniswapV2Pair(pair).balanceOf(alice), liquidity);
        // MINIMUM_LIQUIDITY permanently locked at address(0)
        assertEq(IUniswapV2Pair(pair).balanceOf(address(0)), 1000);
    }

    function test_AddLiquidityETH_WrapsAndMints() public {
        uint256 tokenAmount = 50_000e18;
        uint256 ethAmount = 50 ether;

        vm.prank(owner);
        tokenA.transfer(alice, tokenAmount);
        vm.deal(alice, ethAmount);

        vm.startPrank(alice);
        tokenA.approve(address(router), type(uint256).max);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: ethAmount}(
            address(tokenA), tokenAmount, 0, 0, alice, _deadline()
        );
        vm.stopPrank();

        assertEq(amountToken, tokenAmount);
        assertEq(amountETH, ethAmount);
        assertGt(liquidity, 0);
        assertEq(factory.getPair(address(tokenA), address(weth)) != address(0), true);
    }

    function test_SwapExactTokensForTokens_ReceivesOutput() public {
        _addDefaultLiquidity(alice);
        _seedAndApprove(bob, 1_000e18, 0);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 bobBBefore = tokenB.balanceOf(bob);

        vm.prank(bob);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            1_000e18, 0, path, bob, _deadline()
        );

        assertEq(amounts[0], 1_000e18);
        assertGt(amounts[1], 0);
        assertEq(tokenB.balanceOf(bob), bobBBefore + amounts[1]);
        // 0.3% fee: output < input at 1:1 pool
        assertLt(amounts[1], 1_000e18);
    }

    function test_SwapExactETHForTokens_ReceivesTokens() public {
        // seed tokenA/WETH pool
        uint256 tokenAmount = 50_000e18;
        uint256 ethAmount = 50 ether;
        vm.prank(owner);
        tokenA.transfer(alice, tokenAmount);
        vm.deal(alice, ethAmount + 1 ether);
        vm.startPrank(alice);
        tokenA.approve(address(router), type(uint256).max);
        router.addLiquidityETH{value: ethAmount}(address(tokenA), tokenAmount, 0, 0, alice, _deadline());
        vm.stopPrank();

        vm.deal(bob, 1 ether);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);

        uint256 before_ = tokenA.balanceOf(bob);
        vm.prank(bob);
        uint256[] memory amounts = router.swapExactETHForTokens{value: 1 ether}(0, path, bob, _deadline());

        assertEq(amounts[0], 1 ether);
        assertGt(amounts[1], 0);
        assertEq(tokenA.balanceOf(bob), before_ + amounts[1]);
    }

    function test_RemoveLiquidity_ReturnsBothTokens() public {
        uint256 liquidity = _addDefaultLiquidity(alice);
        address pair = factory.getPair(address(tokenA), address(tokenB));

        uint256 aBefore = tokenA.balanceOf(alice);
        uint256 bBefore = tokenB.balanceOf(alice);

        vm.startPrank(alice);
        IUniswapV2Pair(pair).approve(address(router), liquidity);
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA), address(tokenB), liquidity, 0, 0, alice, _deadline()
        );
        vm.stopPrank();

        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertEq(tokenA.balanceOf(alice), aBefore + amountA);
        assertEq(tokenB.balanceOf(alice), bBefore + amountB);
        assertEq(IUniswapV2Pair(pair).balanceOf(alice), 0);
    }

    function test_RevertWhen_DeadlineExpired() public {
        _seedAndApprove(alice, LIQ_A, LIQ_B);
        uint256 expired = block.timestamp - 1;

        vm.prank(alice);
        vm.expectRevert(bytes("UniswapV2Router: EXPIRED"));
        router.addLiquidity(
            address(tokenA), address(tokenB), LIQ_A, LIQ_B, 0, 0, alice, expired
        );
    }

    function test_RevertWhen_SwapSlippageExceeded() public {
        _addDefaultLiquidity(alice);
        _seedAndApprove(bob, 1_000e18, 0);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.prank(bob);
        vm.expectRevert(bytes("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"));
        router.swapExactTokensForTokens(1_000e18, type(uint256).max, path, bob, _deadline());
    }

    function test_GetAmountsOut_MatchesSwap() public {
        _addDefaultLiquidity(alice);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256[] memory quoted = router.getAmountsOut(500e18, path);

        _seedAndApprove(bob, 500e18, 0);
        vm.prank(bob);
        uint256[] memory amounts = router.swapExactTokensForTokens(500e18, 0, path, bob, _deadline());

        assertEq(amounts[0], quoted[0]);
        assertEq(amounts[1], quoted[1]);
    }

    function testFuzz_SwapExactTokensForTokens_OutputPositive(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e15, 5_000e18);
        _addDefaultLiquidity(alice);
        _seedAndApprove(bob, amountIn, 0);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.prank(bob);
        uint256[] memory amounts = router.swapExactTokensForTokens(amountIn, 0, path, bob, _deadline());

        assertEq(amounts[0], amountIn);
        assertGt(amounts[1], 0);
        assertLt(amounts[1], amountIn); // fee + price impact at balanced pool for amountIn << reserve
    }
}
