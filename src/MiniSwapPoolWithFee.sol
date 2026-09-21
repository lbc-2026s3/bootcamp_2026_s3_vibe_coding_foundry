// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MiniSwapPool} from "./MiniSwapPool.sol";

/// @notice MiniSwapPoolWithFee:继承 MiniSwapPool,采用 Uniswap V2 风格的 swap fee
/// 手续费 3‰(0.3%)以"输入代币"计价,留在池子储备里,使 k 随每次兑换增长
/// 收益自动按 LP 份额分配给所有流动性提供者,无需单独记账、无需 owner
///
/// @dev 实现方式:只重写 getAmountOut,不重写 swap。
///   - amountOut 用 amountInAfterFee = amountIn * 997 / 1000 代入 x*y=k 计算(用户少拿一点)
///   - 但返回的 newReserve_in 用完整 amountIn 计入(池子多留一点)
///   两者之差 = amountIn * 3 / 1000,就是留在池里的手续费,让 k_new > k_old
///
///   父合约 swap 内部调用 getAmountOut 时,经虚函数分派(virtual dispatch)
///   会走到本合约的 override 实现,因此 swap 无需重写——手续费逻辑全部封装在 getAmountOut 里。
contract MiniSwapPoolWithFee is MiniSwapPool {
    /// @notice 手续费分子,3 表示 3‰(千分之三 = 0.3%)
    uint256 public constant FEE_NUMERATOR = 3;

    /// @notice 手续费分母,千分比
    uint256 public constant FEE_DENOMINATOR = 1000;

    constructor(
        address _token0,
        address _token1,
        string memory name,
        string memory symbol
    ) MiniSwapPool(_token0, _token1, name, symbol) {}

    /// @notice 计算含手续费的输出数量与兑换后的储备量
    /// @dev Uniswap V2 风格:
    ///   amountOut 按 amountInAfterFee 守恒 k 求出(用户少拿一点);
    ///   但 newReserve_in 计入完整 amountIn(池子多留一点)。
    ///   两者之差 = amountIn * FEE_NUMERATOR / FEE_DENOMINATOR,就是留在池里的手续费,
    ///   它让 k_new > k_old,自动归所有 LP 按份额享有。
    function getAmountOut(
        uint256 amountIn,
        address fromToken
    )
        public
        view
        override
        returns (uint256 amountOut, uint256 _reserve0, uint256 _reserve1)
    {
        uint256 amountInAfterFee = (amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR)) / FEE_DENOMINATOR;
        uint256 k = reserve0 * reserve1;
        uint256 newReserve0;
        uint256 newReserve1;

        if (fromToken == token0) {
            // 用 amountInAfterFee 守恒 k 求输出
            uint256 newReserve0AfterFee = amountInAfterFee + reserve0;
            uint256 newReserve1AfterFee = k / newReserve0AfterFee;
            amountOut = reserve1 - newReserve1AfterFee;
            // 但储备量计入完整 amountIn,k 因此增长
            newReserve0 = reserve0 + amountIn;
            newReserve1 = reserve1 - amountOut;
        } else {
            uint256 newReserve1AfterFee = amountInAfterFee + reserve1;
            uint256 newReserve0AfterFee = k / newReserve1AfterFee;
            amountOut = reserve0 - newReserve0AfterFee;
            newReserve1 = reserve1 + amountIn;
            newReserve0 = reserve0 - amountOut;
        }

        _reserve0 = newReserve0;
        _reserve1 = newReserve1;
    }
}
