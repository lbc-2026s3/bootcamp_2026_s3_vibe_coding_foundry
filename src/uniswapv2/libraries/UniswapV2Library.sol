// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import '../interfaces/IUniswapV2Pair.sol';
import '../UniswapV2Pair.sol';
import "./SafeMath.sol";

/// @notice Router 用的纯计算 / 地址工具库：排序、CREATE2 算 pair、读储备、询价。
/// @dev 恒定乘积 / 手续费 / 多跳询价公式推导见同目录 `UniswapV2Library.md`。
library UniswapV2Library {
    using SafeMath for uint;

    /// @notice 按地址大小排序为 (token0, token1)。Pair 内储备也按此顺序存放。
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    /// @notice 不发外部调用，用 CREATE2 公式算出 pair 地址。
    /// @dev 本 fork 用 live `UniswapV2Pair.creationCode` 算 init code hash，与当前 Foundry 编译结果一致（≠ 主网硬编码 hash）。
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        // CREATE2：keccak256(0xff ++ factory ++ salt ++ initCodeHash)
        // salt = keccak256(token0, token1)；initCodeHash = keccak256(Pair.creationCode)
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                keccak256(type(UniswapV2Pair).creationCode)
            )))));
    }

    /// @notice 读取 pair 储备，并按调用方传入的 (tokenA, tokenB) 顺序返回 (reserveA, reserveB)。
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /// @notice 按储备比例换算：给定 amountA，求等值 amountB（无手续费）。amountB = amountA * reserveB / reserveA。
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    /// @notice 单跳精确输入：投入 amountIn，最多能换出多少 amountOut（含 0.3% 手续费，即 ×997/1000）。
    /// @dev 公式见 `UniswapV2Library.md` § getAmountOut。
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    /// @notice 单跳精确输出：想得到 amountOut，最少需要投入多少 amountIn（含 0.3% 手续费；结果向上取整 +1）。
    /// @dev 公式见 `UniswapV2Library.md` § getAmountIn。
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    /// @notice 多跳精确输入：沿 path 链式调用 getAmountOut。amounts[0]=amountIn，amounts[last]=最终输出。
    /// @dev 公式见 `UniswapV2Library.md` § getAmountsOut / getAmountsIn。
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /// @notice 多跳精确输出：沿 path 从后往前链式调用 getAmountIn。amounts[last]=amountOut，amounts[0]=所需总输入。
    /// @dev 公式见 `UniswapV2Library.md` § getAmountsOut / getAmountsIn。
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
