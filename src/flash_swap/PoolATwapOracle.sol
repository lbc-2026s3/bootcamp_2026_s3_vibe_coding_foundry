// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IUniswapV2Pair} from "uniswapv2/interfaces/IUniswapV2Pair.sol";
import {UQ112x112} from "uniswapv2/libraries/UQ112x112.sol";

/// @notice PoolA（Uniswap V2 Pair）固定窗口 TWAP 预言机。
/// @dev 仿 Uniswap `ExampleOracleSimple`：每过 `period` 秒可 `update()` 一次，
///      TWAP = (priceCumulative_now - priceCumulative_last) / timeElapsed。
///      价格为 UQ112x112；`consult` 按该均价换算 amountOut。
contract PoolATwapOracle {
    using UQ112x112 for uint224;

    address public immutable pair;
    address public immutable token0;
    address public immutable token1;
    /// @notice 最小观测窗口（秒），两次 update 至少间隔这么久
    uint32 public immutable period;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;

    /// @notice token1/token0 的时间加权均价（UQ112x112）
    uint224 public price0Average;
    /// @notice token0/token1 的时间加权均价（UQ112x112）
    uint224 public price1Average;

    bool public updated;

    event TwapUpdated(
        uint256 price0Average,
        uint256 price1Average,
        uint32 timeElapsed,
        uint32 timestamp
    );

    /// @param pair_ PoolA 地址（已有流动性）
    /// @param period_ 窗口秒数，例如 1 hours；测试里可设较短值
    constructor(address pair_, uint32 period_) {
        require(pair_ != address(0), "zero pair");
        require(period_ > 0, "zero period");

        IUniswapV2Pair p = IUniswapV2Pair(pair_);
        pair = pair_;
        token0 = p.token0();
        token1 = p.token1();
        period = period_;

        price0CumulativeLast = p.price0CumulativeLast();
        price1CumulativeLast = p.price1CumulativeLast();
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = p.getReserves();
        require(reserve0 > 0 && reserve1 > 0, "NO_RESERVES");
    }

    /// @notice 读取当前累计价（若本块尚未 sync，用储备反事实补到 now）
    function currentCumulativePrices()
        public
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp)
    {
        blockTimestamp = uint32(block.timestamp % 2 ** 32);
        price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast_) = IUniswapV2Pair(pair).getReserves();
        if (blockTimestampLast_ != blockTimestamp) {
            uint32 timeElapsed;
            unchecked {
                timeElapsed = blockTimestamp - blockTimestampLast_;
            }
            // 与 Pair._update 相同：UQ112x112 价格 × 秒
            price0Cumulative += uint256(UQ112x112.encode(reserve1).uqdiv(reserve0)) * timeElapsed;
            price1Cumulative += uint256(UQ112x112.encode(reserve0).uqdiv(reserve1)) * timeElapsed;
        }
    }

    /// @notice 窗口结束后刷新 TWAP；可被任何人调用
    function update() external {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = currentCumulativePrices();

        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast;
        }
        require(timeElapsed >= period, "PERIOD_NOT_ELAPSED");

        unchecked {
            // cumulative 为 UQ112x112×seconds；除以 timeElapsed 得 UQ112x112 均价
            price0Average = uint224((price0Cumulative - price0CumulativeLast) / timeElapsed);
            price1Average = uint224((price1Cumulative - price1CumulativeLast) / timeElapsed);
        }

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
        // 仅标记「至少成功 update 过一次」，供 consult / twapPrice1Per0 使用；
        // 不阻止后续再 update：每隔 period 秒仍可再次刷新 TWAP。
        updated = true;

        emit TwapUpdated(price0Average, price1Average, timeElapsed, blockTimestamp);
    }

    /// @notice 用最新 TWAP 询价：投入 amountIn 个 token，能换多少另一侧代币
    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut) {
        require(updated, "NOT_UPDATED");
        require(amountIn > 0, "zero amount");

        if (token == token0) {
            // amountOut = price0Average * amountIn / 2^112
            amountOut = (uint256(price0Average) * amountIn) >> 112;
        } else {
            require(token == token1, "INVALID_TOKEN");
            amountOut = (uint256(price1Average) * amountIn) >> 112;
        }
    }

    /// @notice 现货价 token1/token0，缩放 1e18
    /// @dev 实时价格（spot）不安全：单笔 swap / 闪电贷可在同一交易内操纵，勿作清算、借贷抵押率等定价依据。
    function spotPrice1Per0() external view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        require(reserve0 > 0, "NO_RESERVES");
        return (uint256(reserve1) * 1e18) / uint256(reserve0);
    }

    /// @notice TWAP 价 token1/token0，缩放 1e18（需先 update）
    /// @dev 时间加权平均价格相对安全：操纵需在整个 `period` 内持续顶价，成本更高；仍需合理窗口与二次校验。
    function twapPrice1Per0() external view returns (uint256) {
        require(updated, "NOT_UPDATED");
        return (uint256(price0Average) * 1e18) >> 112;
    }
}
