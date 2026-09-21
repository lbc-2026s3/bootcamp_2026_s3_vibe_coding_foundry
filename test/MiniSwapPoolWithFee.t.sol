// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MiniSwapPoolWithFee} from "../src/MiniSwapPoolWithFee.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";

/// @notice MiniSwapPoolWithFee 单元测试:Uniswap V2 风格 swap fee
/// 验证手续费留在池子里、k 增长、LP 按份额受益、无需 owner
contract MiniSwapPoolWithFeeTest is Test {
    MiniSwapPoolWithFee public pool;
    MyTokenV1 public token0;
    MyTokenV1 public token1;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        vm.startPrank(owner);
        token0 = new MyTokenV1();
        token1 = new MyTokenV1();
        pool = new MiniSwapPoolWithFee(
            address(token0),
            address(token1),
            "MiniSwapPoolWithFee",
            "MSPF"
        );
        vm.stopPrank();
    }

    function _seedUser(address user, uint256 amount0, uint256 amount1) internal {
        vm.startPrank(owner);
        token0.transfer(user, amount0);
        token1.transfer(user, amount1);
        vm.stopPrank();

        vm.startPrank(user);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function test_Constructor_SetsFee() public view {
        assertEq(pool.FEE_NUMERATOR(), 3);
        assertEq(pool.FEE_DENOMINATOR(), 1000);
        assertEq(pool.token0(), address(token0));
        assertEq(pool.token1(), address(token1));
    }

    function test_GetAmountOut_DeductsFeeAndGrowsK() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        uint256 amountIn = 1_000e18;
        uint256 amountInAfterFee = (amountIn * 997) / 1000;

        (uint256 amountOut, uint256 newReserve0, uint256 newReserve1) = pool
            .getAmountOut(amountIn, address(token0));

        // 输出按 amountInAfterFee 守恒 k 求出
        uint256 kBefore = 10_100e18 * 6_060e18;
        uint256 kAfterFee = (10_100e18 + amountInAfterFee) * (6_060e18 - amountOut);
        assertLe(kAfterFee, kBefore);
        assertGe(kAfterFee, kBefore - 11_100e18);

        // 但返回的储备量计入完整 amountIn,k 因此增长
        assertEq(newReserve0, 10_100e18 + amountIn);
        assertEq(newReserve1, 6_060e18 - amountOut);
        uint256 kNew = newReserve0 * newReserve1;
        assertGt(kNew, kBefore);
        assertGt(amountOut, 0);
    }

    function test_Swap_FeeStaysInPoolAndKGrows() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        _seedUser(bob, 1_000e18, 1_000e18);

        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        uint256 amountIn = 1_000e18;
        uint256 kBefore = pool.reserve0() * pool.reserve1();

        vm.startPrank(bob);
        pool.swap(amountIn, 1, address(token0), address(token1), bob);
        vm.stopPrank();

        // 池子拿到完整 amountIn(没有手续费被转出)
        assertEq(
            token0.balanceOf(address(pool)),
            10_100e18 + amountIn
        );
        // k 严格增长(手续费留在池里)
        uint256 kAfter = pool.reserve0() * pool.reserve1();
        assertGt(kAfter, kBefore);
    }

    function test_Swap_OtherDirection_FeeStaysInPool() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        _seedUser(bob, 1_000e18, 1_000e18);

        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        uint256 amountIn = 1_000e18;
        uint256 kBefore = pool.reserve0() * pool.reserve1();

        vm.startPrank(bob);
        pool.swap(amountIn, 1, address(token1), address(token0), bob);
        vm.stopPrank();

        assertEq(token1.balanceOf(address(pool)), 6_060e18 + amountIn);
        assertGt(pool.reserve0() * pool.reserve1(), kBefore);
    }

    function test_Swap_LPBenefitsFromAccruedFees() public {
        // alice 是唯一 LP,bob 反复兑换累积手续费
        // alice 拥有 100% LP,移除全部流动性会抽干池子,拿回的就是兑换后的全部储备
        // 因为 k 增长且 totalSupply 不变,她赎回量的乘积应 > 存入量的乘积
        _seedUser(alice, 10_100e18, 6_060e18);
        _seedUser(bob, 10_000e18, 10_000e18);

        uint256 depositProduct = 10_100e18 * 6_060e18;

        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);
        uint256 aliceLp = pool.balanceOf(alice);

        // bob 来回兑换几次,累积手续费
        vm.startPrank(bob);
        for (uint256 i = 0; i < 3; i++) {
            pool.swap(500e18, 1, address(token0), address(token1), bob);
            pool.swap(500e18, 1, address(token1), address(token0), bob);
        }
        vm.stopPrank();

        // alice 移除全部流动性,抽干池子
        uint256 aliceT0Before = token0.balanceOf(alice);
        uint256 aliceT1Before = token1.balanceOf(alice);
        vm.prank(alice);
        pool.remove(aliceLp);

        uint256 redeemed0 = token0.balanceOf(alice) - aliceT0Before;
        uint256 redeemed1 = token1.balanceOf(alice) - aliceT1Before;

        // k 增长 + alice 拿走全部储备 → 赎回量的乘积严格大于存入量的乘积
        assertGt(redeemed0 * redeemed1, depositProduct);
    }

    function test_RevertWhen_Swap_ZeroAmountIn() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        vm.prank(alice);
        vm.expectRevert("Amount invalid");
        pool.swap(0, 1, address(token0), address(token1), alice);
    }

    function test_RevertWhen_Swap_SlippageExceeded() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        vm.prank(alice);
        vm.expectRevert("Slipped... on a banana");
        pool.swap(100e18, type(uint256).max, address(token0), address(token1), alice);
    }

    function testFuzz_Swap_KAlwaysGrows(uint256 amountIn) public {
        _seedUser(alice, 10_100e18, 6_060e18);
        _seedUser(bob, 500_000e18, 500_000e18);

        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        amountIn = bound(amountIn, 1e18, 1_000e18);
        uint256 kBefore = pool.reserve0() * pool.reserve1();

        vm.startPrank(bob);
        pool.swap(amountIn, 1, address(token0), address(token1), bob);
        vm.stopPrank();

        // 手续费留在池里,k 严格增长
        assertGt(pool.reserve0() * pool.reserve1(), kBefore);
    }
}
