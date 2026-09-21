// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

/// @notice MiniSwapPool:基于 x*y=k 恒定乘积公式的极简 AMM 池
/// @dev fork from https://github.com/monokh/looneyswap
/// 池本身是一个 ERC20(LP Token),添加流动性时铸造 LP,移除流动性时销毁 LP
/// 使用 SafeERC20,兼容 USDT 等 transfer/transferFrom 不返回 bool 的非标准代币
contract MiniSwapPool is ERC20 {
    using SafeERC20 for IERC20;

    address public token0;
    address public token1;

    /// @notice token0 的储备量
    uint256 public reserve0;

    /// @notice token1 的储备量
    uint256 public reserve1;

    constructor(
        address _token0,
        address _token1,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        token0 = _token0;
        token1 = _token1;
    }

    /// @notice 添加流动性
    /// 1. 将 token 转入池子
    /// 2. 铸造 LP 代币
    /// 3. 多给的那一边退还给 msg.sender(避免非对称注入被吞)
    /// 4. 更新储备量
    function addLiquidity(uint256 amount0, uint256 amount1) public {
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        if (reserve0 == 0 && reserve1 == 0) {
            // 首次添加流动性:LP 供应量 = sqrt(amount0 * amount1)
            // sqrt 使供应量随首存规模等比缩放,后续小存款拿到 sqrt(小) > 0 的 LP,不会被截断为 0
            // 这正是抵御"首存者拉高兑换率吞掉后续小存款"攻击的关键
            uint256 initialLiquidity = Math.sqrt(amount0 * amount1);
            require(initialLiquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
            _mint(msg.sender, initialLiquidity);
            reserve0 = amount0;
            reserve1 = amount1;
            return;
        }

        // 原则：新 LP 占总 LP 的比例 = 新注入价值占池子总价值的比例
        // 否则要么新 LP 被多铸(白嫖老人),要么少铸(新人吃亏)
        uint256 currentSupply = totalSupply();

        // 按 token0 的增长比例计算,应该有多少总 LP 代币
        // 新储备量0 × 当前LP总量 / 旧储备量0
        uint256 newSupplyGivenReserve0Ratio = (reserve0 + amount0) * currentSupply / reserve0;
        uint256 newSupplyGivenReserve1Ratio = (reserve1 + amount1) * currentSupply / reserve1;

        uint256 usedAmount0 = amount0;
        uint256 usedAmount1 = amount1;
        uint256 newSupply;

        if (newSupplyGivenReserve0Ratio <= newSupplyGivenReserve1Ratio) {
            // token0 是"绑定边":token0 全部计入,token1 多余部分退还
            // 匹配量需满足 usedAmount1 / reserve1 == amount0 / reserve0(保持价格比例)
            newSupply = newSupplyGivenReserve0Ratio;
            usedAmount1 = (amount0 * reserve1) / reserve0;
            uint256 refund1 = amount1 - usedAmount1;
            if (refund1 > 0) {
                IERC20(token1).safeTransfer(msg.sender, refund1);
            }
        } else {
            // token1 是"绑定边":token1 全部计入,token0 多余部分退还
            newSupply = newSupplyGivenReserve1Ratio;
            usedAmount0 = (amount1 * reserve0) / reserve1;
            uint256 refund0 = amount0 - usedAmount0;
            if (refund0 > 0) {
                IERC20(token0).safeTransfer(msg.sender, refund0);
            }
        }

        _mint(msg.sender, newSupply - currentSupply);
        reserve0 = reserve0 + usedAmount0;
        reserve1 = reserve1 + usedAmount1;
    }

    /// @notice 移除流动性
    /// 1. 将 LP 代币转回池子
    /// 2. 销毁 LP 代币
    /// 3. 更新储备量
    function remove(uint256 liquidity) public {
        assert(transfer(address(this), liquidity));

        uint256 currentSupply = totalSupply();

        // 10 lp token ; total 100;
        // LP 代币的本质:1 个 LP = 池子的 1 / totalSupply 份额
        // 可提取的 token0 = liquidity / totalSupply × reserve0
        uint256 amount0 = (liquidity * reserve0) / currentSupply;
        uint256 amount1 = (liquidity * reserve1) / currentSupply;

        _burn(address(this), liquidity); // 1 MSP

        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);
        reserve0 = reserve0 - amount0;
        reserve1 = reserve1 - amount1;
    }

    /// @notice 使用 x * y = k 公式计算输出数量
    /// 1. 计算两侧的新储备量
    /// 2. 推导输出数量
    function getAmountOut(
        uint256 amountIn,
        address fromToken
    ) public view virtual returns (uint256 amountOut, uint256 _reserve0, uint256 _reserve1) {
        uint256 newReserve0;
        uint256 newReserve1;
        uint256 k = reserve0 * reserve1;

        // x (reserve0) * y (reserve1) = k (constant)
        // (reserve0 + amountIn) * (reserve1 - amountOut) = k
        // (reserve1 - amountOut) = k / (reserve0 + amountIn)
        // newReserve1 = k / newReserve0
        // amountOut = reserve1 - newReserve1

        if (fromToken == token0) {
            newReserve0 = amountIn + reserve0;
            newReserve1 = k / newReserve0;
            amountOut = reserve1 - newReserve1;
        } else {
            newReserve1 = amountIn + reserve1;
            newReserve0 = k / newReserve1;
            amountOut = reserve0 - newReserve0;
        }

        _reserve0 = newReserve0;
        _reserve1 = newReserve1;
    }

    /// @notice 兑换,最少换出 `minAmountOut`
    /// 1. 计算两侧的新储备量
    /// 2. 推导输出数量
    /// 3. 校验输出数量是否满足最小要求
    /// 4. 更新储备量
    function swap(
        uint256 amountIn,
        uint256 minAmountOut,
        address fromToken,
        address toToken,
        address to
    ) public {
        require(amountIn > 0 && minAmountOut > 0, "Amount invalid");
        require(
            fromToken == token0 || fromToken == token1,
            "From token invalid"
        );
        require(toToken == token0 || toToken == token1, "To token invalid");
        require(fromToken != toToken, "From and to tokens should not match");

        (uint256 amountOut, uint256 newReserve0, uint256 newReserve1) = getAmountOut(
            amountIn,
            fromToken
        );

        require(amountOut >= minAmountOut, "Slipped... on a banana");

        IERC20(fromToken).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(toToken).safeTransfer(to, amountOut);

        reserve0 = newReserve0;
        reserve1 = newReserve1;
    }
}
