// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Callee} from "uniswapv2/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2Pair} from "uniswapv2/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Library} from "uniswapv2/libraries/UniswapV2Library.sol";

/// @notice 跨两个 Uniswap V2 Factory 的闪电兑换套利（不依赖 Router，直接 Pair.swap）。
/// @dev 从 `borrowFactory` 的 pair 借入，在 `sellFactory` 的对应 pair 卖出，再还款；利润转给 `profitReceiver`。
///
/// 典型价差:
///   PoolA (borrowFactory): 1 MT1 = 2 MT2
///   PoolB (sellFactory):   1 MT1 = 1 MT2
/// 流程: 从 PoolA 借 MT2 → 在 PoolB 换成 MT1 → 用 MT1 还给 PoolA，多余 MT1 为利润。
contract FlashSwapArbitrage is IUniswapV2Callee {
    using SafeERC20 for IERC20;

    address public immutable borrowFactory;
    address public immutable sellFactory;
    address public immutable profitReceiver;

    event ArbitrageExecuted(
        address indexed pair,
        address indexed borrowToken,
        uint256 borrowAmount,
        address indexed profitToken,
        uint256 profit
    );

    constructor(address borrowFactory_, address sellFactory_, address profitReceiver_) {
        require(borrowFactory_ != address(0) && sellFactory_ != address(0), "zero address");
        require(profitReceiver_ != address(0), "zero profit receiver");
        borrowFactory = borrowFactory_;
        sellFactory = sellFactory_;
        profitReceiver = profitReceiver_;
    }

    /// @notice 从 `pair` 闪电借入 `borrowToken` 数量 `amount`，在另一 Factory 卖出并还款。
    function flashSwap(address pair, address borrowToken, uint256 amount) external {
        require(amount > 0, "zero amount");
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        require(pair == UniswapV2Library.pairFor(borrowFactory, token0, token1), "invalid pair");
        require(borrowToken == token0 || borrowToken == token1, "invalid borrow token");

        // data 非空会触发 pair 回调 uniswapV2Call, 这里用 new bytes(1) 作为 data
        if (borrowToken == token0) {
            IUniswapV2Pair(pair).swap(amount, 0, address(this), new bytes(1));
        } else {
            IUniswapV2Pair(pair).swap(0, amount, address(this), new bytes(1));
        }
    }

    /// @inheritdoc IUniswapV2Callee
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata) external override {
        require(sender == address(this), "invalid sender");
        require(amount0 == 0 || amount1 == 0, "invalid amounts");

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        require(msg.sender == UniswapV2Library.pairFor(borrowFactory, token0, token1), "invalid caller");

        if (amount0 > 0) {
            // 借到了 amount0 数量的 token0, 进行套利并还款（token1作为还款token）
            _arbAndRepay(token0, token1, amount0, msg.sender);
            return;
        }
        // 借到了 amount1 数量的 token1, 进行套利并还款（token0作为还款token）
        _arbAndRepay(token1, token0, amount1, msg.sender);
    }

    function _arbAndRepay(address borrowToken, address repayToken, uint256 borrowAmount, address borrowPair)
        private
    {
        // 借入侧：还 borrowAmount 个 borrowToken，至少需要多少 repayToken（含 0.3% 手续费）
        address[] memory repayPath = new address[](2);
        repayPath[0] = repayToken;
        repayPath[1] = borrowToken;
        uint256 amountRequired = UniswapV2Library.getAmountsIn(borrowFactory, borrowAmount, repayPath)[0];

        // 卖出侧：直接在 sellFactory 的 pair 上用 borrowToken 换 repayToken
        address[] memory sellPath = new address[](2);
        sellPath[0] = borrowToken;
        sellPath[1] = repayToken;
        uint256 amountReceived = UniswapV2Library.getAmountsOut(sellFactory, borrowAmount, sellPath)[1];
        // 套利失败
        require(amountReceived > amountRequired, "unprofitable");

        address sellPair = UniswapV2Library.pairFor(sellFactory, borrowToken, repayToken);
        IERC20(borrowToken).safeTransfer(sellPair, borrowAmount);

        (address token0,) = UniswapV2Library.sortTokens(borrowToken, repayToken);
        (uint256 amount0Out, uint256 amount1Out) =
            borrowToken == token0 ? (uint256(0), amountReceived) : (amountReceived, uint256(0));
        // data 为空：普通 swap，不触发回调
        IUniswapV2Pair(sellPair).swap(amount0Out, amount1Out, address(this), new bytes(0));

        // 还款
        IERC20(repayToken).safeTransfer(borrowPair, amountRequired);
        uint256 profit = amountReceived - amountRequired;
        // 利润转给 profitReceiver
        IERC20(repayToken).safeTransfer(profitReceiver, profit);

        emit ArbitrageExecuted(borrowPair, borrowToken, borrowAmount, repayToken, profit);
    }
}
