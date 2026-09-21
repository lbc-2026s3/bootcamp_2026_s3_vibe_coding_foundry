// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MiniSwapPool} from "../src/MiniSwapPool.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";

/// @notice MiniSwapPool 单元测试:覆盖添加流动性 / 移除流动性 / 兑换 / x*y=k 计算
contract MiniSwapPoolTest is Test {
    MiniSwapPool public pool;
    MyTokenV1 public token0;
    MyTokenV1 public token1;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        vm.startPrank(owner);
        token0 = new MyTokenV1();
        token1 = new MyTokenV1();
        pool = new MiniSwapPool(
            address(token0),
            address(token1),
            "MiniSwapPool",
            "MSP"
        );
        vm.stopPrank();
    }

    /// @dev 给 user 授权 pool 操作其 token,并补充一些余额
    /// owner 持有全部初始代币,所以转账必须以 owner 身份执行
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

    function test_Constructor_SetsTokensAndMetadata() public view {
        assertEq(pool.token0(), address(token0));
        assertEq(pool.token1(), address(token1));
        assertEq(pool.name(), "MiniSwapPool");
        assertEq(pool.symbol(), "MSP");
    }

    function test_AddLiquidity_FirstTimeMintsSqrtProportional() public {
        _seedUser(alice, 10_100e18, 6_060e18);

        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        assertEq(pool.reserve0(), 10_100e18);
        assertEq(pool.reserve1(), 6_060e18);
        // initialLiquidity = sqrt(10100 * 6060) = sqrt(61206000) = 7823(向下取整)
        uint256 initialLiquidity = sqrt(10_100e18 * 6_060e18);
        assertEq(pool.balanceOf(alice), initialLiquidity);
        assertEq(pool.totalSupply(), initialLiquidity);
    }

    function test_RevertWhen_AddLiquidity_FirstTimeZeroOnOneSide() public {
        // 一边为 0 → sqrt(0) = 0 → revert
        _seedUser(alice, 1000, 0);
        vm.prank(alice);
        vm.expectRevert("INSUFFICIENT_LIQUIDITY_MINTED");
        pool.addLiquidity(1000, 0);
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        // Babylonian method
        if (x == 0) return 0;
        uint256 z = x;
        uint256 y = (x + 1) / 2;
        while (y < z) {
            z = y;
            y = (x / y + y) / 2;
        }
        return z;
    }

    function test_AddLiquidity_SecondTimeMintsProportionally() public {
        _seedUser(alice, 20_200e18, 12_120e18);
        _seedUser(bob, 10_100e18, 6_060e18);

        // alice 首次添加,获得 sqrt(10100*6060) - MINIMUM_LIQUIDITY
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);
        uint256 aliceLp = pool.balanceOf(alice);

        // bob 按相同比例添加,应获得与 alice 相同数量的 LP
        vm.prank(bob);
        pool.addLiquidity(10_100e18, 6_060e18);

        assertEq(pool.balanceOf(bob), aliceLp);
        assertEq(pool.totalSupply(), aliceLp * 2);
        assertEq(pool.reserve0(), 20_200e18);
        assertEq(pool.reserve1(), 12_120e18);
    }

    function test_AddLiquidity_AsymmetricMintsBySmallerRatioAndRefundsExcess() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        _seedUser(bob, 1_010e18, 6_060e18);

        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);
        uint256 aliceLp = pool.balanceOf(alice);

        uint256 bobT0Before = token0.balanceOf(bob);
        uint256 bobT1Before = token1.balanceOf(bob);

        // bob 只按 token0 比例(1/10)添加,token1 给多了——按较小比例铸造,多余 token1 退还
        vm.prank(bob);
        pool.addLiquidity(1_010e18, 6_060e18);

        assertEq(pool.balanceOf(bob), aliceLp / 10);

        // 匹配的 token1 = amount0 * reserve1 / reserve0 = 1010 * 6060 / 10100 = 606
        uint256 matched1 = (1_010e18 * 6_060e18) / 10_100e18;
        uint256 refund1 = 6_060e18 - matched1;
        // token0 全部计入(0 退还),token1 退还多余部分
        assertEq(token0.balanceOf(bob), bobT0Before - 1_010e18);
        assertEq(token1.balanceOf(bob), bobT1Before - 6_060e18 + refund1);
        assertEq(pool.reserve0(), 11_110e18);
        assertEq(pool.reserve1(), 6_060e18 + matched1);
    }

    function test_AddLiquidity_AsymmetricOtherSideRefundsExcessToken0() public {
        // 反向:token1 是绑定边,token0 多给
        _seedUser(alice, 10_100e18, 6_060e18);
        _seedUser(bob, 6_060e18, 606e18);

        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);
        uint256 aliceLp = pool.balanceOf(alice);

        uint256 bobT0Before = token0.balanceOf(bob);
        uint256 bobT1Before = token1.balanceOf(bob);

        // bob 给 6060 token0 + 606 token1,token1 比例(1/10)更小,token0 多余退还
        vm.prank(bob);
        pool.addLiquidity(6_060e18, 606e18);

        assertEq(pool.balanceOf(bob), aliceLp / 10);

        // 匹配的 token0 = amount1 * reserve0 / reserve1 = 606 * 10100 / 6060 = 1010
        uint256 matched0 = (606e18 * 10_100e18) / 6_060e18;
        uint256 refund0 = 6_060e18 - matched0;
        assertEq(token0.balanceOf(bob), bobT0Before - 6_060e18 + refund0);
        assertEq(token1.balanceOf(bob), bobT1Before - 606e18);
        assertEq(pool.reserve0(), 10_100e18 + matched0);
        assertEq(pool.reserve1(), 6_060e18 + 606e18);
    }

    function test_AddLiquidity_SymmetricNoRefund() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        _seedUser(bob, 10_100e18, 6_060e18);

        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);
        uint256 aliceLp = pool.balanceOf(alice);

        // 完全按比例注入,不应有任何退还:两边全部计入池子
        vm.prank(bob);
        pool.addLiquidity(10_100e18, 6_060e18);

        assertEq(pool.balanceOf(bob), aliceLp);
        assertEq(token0.balanceOf(bob), 0);
        assertEq(token1.balanceOf(bob), 0);
        assertEq(pool.reserve0(), 20_200e18);
        assertEq(pool.reserve1(), 12_120e18);
    }

    function test_Remove_TransfersTokensProportionalToLp() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        uint256 aliceLp = pool.balanceOf(alice);
        uint256 halfLp = aliceLp / 2;

        uint256 aliceT0Before = token0.balanceOf(alice);
        uint256 aliceT1Before = token1.balanceOf(alice);

        vm.prank(alice);
        pool.remove(halfLp);

        // 移除一半 LP,应拿回一半储备
        assertEq(token0.balanceOf(alice), aliceT0Before + 10_100e18 / 2);
        assertEq(token1.balanceOf(alice), aliceT1Before + 6_060e18 / 2);
        assertEq(pool.reserve0(), 10_100e18 / 2);
        assertEq(pool.reserve1(), 6_060e18 / 2);
        assertEq(pool.balanceOf(alice), aliceLp - halfLp);
    }

    function test_Remove_AllDrainsPool() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        uint256 aliceLp = pool.balanceOf(alice);
        uint256 aliceT0Before = token0.balanceOf(alice);

        vm.prank(alice);
        pool.remove(aliceLp);

        assertEq(token0.balanceOf(alice), aliceT0Before + 10_100e18);
        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
        assertEq(pool.totalSupply(), 0);
    }

    function test_GetAmountOut_RespectsConstantProduct() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        // 用 100 token0 换 token1
        (uint256 amountOut, uint256 newReserve0, uint256 newReserve1) = pool
            .getAmountOut(100e18, address(token0));

        // k 守恒(允许向下取整误差,约几千 e18 量级)
        uint256 kBefore = 10_100e18 * 6_060e18;
        assertLe(newReserve0 * newReserve1, kBefore);
        assertGe(newReserve0 * newReserve1, kBefore - 10_000e18);
        assertGt(amountOut, 0);
        assertEq(newReserve0, 10_100e18 + 100e18);
        assertEq(newReserve1, 6_060e18 - amountOut);
    }

    function test_Swap_TransfersTokensAndUpdatesReserves() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        _seedUser(bob, 1_000e18, 1_000e18);

        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        // bob 用 100 token0 换 token1
        vm.startPrank(bob);
        token0.approve(address(pool), type(uint256).max);
        uint256 bobT1Before = token1.balanceOf(bob);
        pool.swap(100e18, 1, address(token0), address(token1), bob);
        vm.stopPrank();

        assertGt(token1.balanceOf(bob), bobT1Before);
        assertEq(token0.balanceOf(address(pool)), 10_100e18 + 100e18);
    }

    function test_RevertWhen_Swap_ZeroAmountIn() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        vm.prank(alice);
        vm.expectRevert("Amount invalid");
        pool.swap(0, 1, address(token0), address(token1), alice);
    }

    function test_RevertWhen_Swap_ZeroMinAmountOut() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        vm.prank(alice);
        vm.expectRevert("Amount invalid");
        pool.swap(100e18, 0, address(token0), address(token1), alice);
    }

    function test_RevertWhen_Swap_InvalidFromToken() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        vm.prank(alice);
        vm.expectRevert("From token invalid");
        pool.swap(100e18, 1, address(0xdead), address(token1), alice);
    }

    function test_RevertWhen_Swap_InvalidToToken() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        vm.prank(alice);
        vm.expectRevert("To token invalid");
        pool.swap(100e18, 1, address(token0), address(0xdead), alice);
    }

    function test_RevertWhen_Swap_SameToken() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        vm.prank(alice);
        vm.expectRevert("From and to tokens should not match");
        pool.swap(100e18, 1, address(token0), address(token0), alice);
    }

    function test_RevertWhen_Swap_SlippageExceeded() public {
        _seedUser(alice, 10_100e18, 6_060e18);
        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        // 要求换出极大数量,必触发滑点保护
        vm.prank(alice);
        vm.expectRevert("Slipped... on a banana");
        pool.swap(100e18, type(uint256).max, address(token0), address(token1), alice);
    }

    function testFuzz_Swap_PreservesConstantProduct(uint256 amountIn) public {
        _seedUser(alice, 10_100e18, 6_060e18);
        _seedUser(bob, 500_000e18, 500_000e18);

        vm.prank(alice);
        pool.addLiquidity(10_100e18, 6_060e18);

        amountIn = bound(amountIn, 1, 1_000e18);

        vm.startPrank(bob);
        token0.approve(address(pool), type(uint256).max);
        pool.swap(amountIn, 1, address(token0), address(token1), bob);
        vm.stopPrank();

        // k 不应增加(因整数除法可能略减)
        // 损失 = kBefore - kAfter = newReserve0 * (k/newReserve0 的小数余数) < newReserve0
        uint256 kAfter = pool.reserve0() * pool.reserve1();
        uint256 kBefore = 10_100e18 * 6_060e18;
        assertLe(kAfter, kBefore);
        // 余数 r < newReserve0 ≤ 10_100e18 + amountIn ≤ 11_100e18
        assertGe(kAfter, kBefore - 11_100e18);
    }
}
