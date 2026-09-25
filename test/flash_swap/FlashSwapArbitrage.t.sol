// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MyToken1} from "../../src/flash_swap/MyToken1.sol";
import {MyToken2} from "../../src/flash_swap/MyToken2.sol";
import {FlashSwapArbitrage} from "../../src/flash_swap/FlashSwapArbitrage.sol";
import {UniswapV2Factory} from "uniswapv2/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "uniswapv2/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Library} from "uniswapv2/libraries/UniswapV2Library.sol";

/// @notice 双池价差 + 闪电兑换套利端到端测试
contract FlashSwapArbitrageTest is Test {
    address public owner = makeAddr("owner");
    address public arbiter = makeAddr("arbiter");

    MyToken1 public token1;
    MyToken2 public token2;
    UniswapV2Factory public factoryA;
    UniswapV2Factory public factoryB;
    address public poolA;
    address public poolB;
    FlashSwapArbitrage public flashSwap;

    uint256 constant POOL_A_MT1 = 100_000e18;
    uint256 constant POOL_A_MT2 = 200_000e18;
    uint256 constant POOL_B_MT1 = 100_000e18;
    uint256 constant POOL_B_MT2 = 100_000e18;
    uint256 constant BORROW_MT2 = 100e18;

    function setUp() public {
        vm.startPrank(owner);

        token1 = new MyToken1();
        token2 = new MyToken2();

        factoryA = new UniswapV2Factory(owner);
        factoryB = new UniswapV2Factory(owner);

        poolA = _seedPool(factoryA, POOL_A_MT1, POOL_A_MT2);
        poolB = _seedPool(factoryB, POOL_B_MT1, POOL_B_MT2);

        // 从 PoolA 借 MT2，在 PoolB 卖出换 MT1 还款；利润给 arbiter
        flashSwap = new FlashSwapArbitrage(address(factoryA), address(factoryB), arbiter);

        vm.stopPrank();
    }

    function _seedPool(UniswapV2Factory factory, uint256 amount1, uint256 amount2)
        internal
        returns (address pair)
    {
        pair = factory.createPair(address(token1), address(token2));
        token1.transfer(pair, amount1);
        token2.transfer(pair, amount2);
        IUniswapV2Pair(pair).mint(owner);
    }

    function test_PoolsHavePriceDisparity() public view {
        (uint256 aReserve1, uint256 aReserve2) =
            UniswapV2Library.getReserves(address(factoryA), address(token1), address(token2));
        (uint256 bReserve1, uint256 bReserve2) =
            UniswapV2Library.getReserves(address(factoryB), address(token1), address(token2));

        assertEq(aReserve1, POOL_A_MT1);
        assertEq(aReserve2, POOL_A_MT2);
        assertEq(aReserve2 * 1e18 / aReserve1, 2e18);

        assertEq(bReserve1, POOL_B_MT1);
        assertEq(bReserve2, POOL_B_MT2);
        assertEq(bReserve2 * 1e18 / bReserve1, 1e18);

        assertTrue(poolA != poolB);
        assertTrue(address(factoryA) != address(factoryB));
    }

    function test_FlashSwapArbitrage_ProfitsInMyToken1() public {
        assertEq(token1.balanceOf(arbiter), 0);

        address[] memory repayPath = new address[](2);
        repayPath[0] = address(token1);
        repayPath[1] = address(token2);
        uint256 amountRequired =
            UniswapV2Library.getAmountsIn(address(factoryA), BORROW_MT2, repayPath)[0];

        address[] memory sellPath = new address[](2);
        sellPath[0] = address(token2);
        sellPath[1] = address(token1);
        uint256 amountExpectedOut =
            UniswapV2Library.getAmountsOut(address(factoryB), BORROW_MT2, sellPath)[1];

        assertGt(amountExpectedOut, amountRequired, "setup should be profitable");

        flashSwap.flashSwap(poolA, address(token2), BORROW_MT2);

        uint256 profit = token1.balanceOf(arbiter);
        assertGt(profit, 0, "arbiter should receive MT1 profit");
        assertEq(profit, amountExpectedOut - amountRequired);
        assertEq(token1.balanceOf(address(flashSwap)), 0);
        assertEq(token2.balanceOf(address(flashSwap)), 0);

        console.log("Borrowed MT2:", BORROW_MT2);
        console.log("Repay MT1 required:", amountRequired);
        console.log("MT1 from PoolB:", amountExpectedOut);
        console.log("Profit MT1:", profit);
    }

    function test_RevertWhen_UnprofitableDirection() public {
        FlashSwapArbitrage reverseArb =
            new FlashSwapArbitrage(address(factoryB), address(factoryA), arbiter);

        vm.expectRevert("unprofitable");
        reverseArb.flashSwap(poolB, address(token2), BORROW_MT2);
    }

    function test_RevertWhen_InvalidPair() public {
        vm.expectRevert("invalid pair");
        flashSwap.flashSwap(poolB, address(token2), BORROW_MT2);
    }

    function test_RevertWhen_ZeroAmount() public {
        vm.expectRevert("zero amount");
        flashSwap.flashSwap(poolA, address(token2), 0);
    }

    function test_RevertWhen_InvalidBorrowToken() public {
        vm.expectRevert("invalid borrow token");
        flashSwap.flashSwap(poolA, makeAddr("fake"), BORROW_MT2);
    }

    function test_RevertWhen_DirectCallbackWrongSender() public {
        vm.expectRevert("invalid sender");
        flashSwap.uniswapV2Call(address(this), 0, BORROW_MT2, new bytes(1));
    }

    function test_PoolsRemainSolventAfterArb() public {
        flashSwap.flashSwap(poolA, address(token2), BORROW_MT2);

        (uint112 r0A, uint112 r1A,) = IUniswapV2Pair(poolA).getReserves();
        (uint112 r0B, uint112 r1B,) = IUniswapV2Pair(poolB).getReserves();
        assertGt(uint256(r0A) * uint256(r1A), 0);
        assertGt(uint256(r0B) * uint256(r1B), 0);
    }
}
