pragma solidity =0.6.6;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';

import '../libraries/UniswapV2Library.sol';
import '../interfaces/V1/IUniswapV1Factory.sol';
import '../interfaces/V1/IUniswapV1Exchange.sol';
import '../interfaces/IUniswapV2Router01.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IWETH.sol';

/// @title ExampleFlashSwap — V2 闪电兑换 + V1 套利示例
/// @notice 利用 Uniswap V2 Pair 的乐观转账（flash swap），在同一笔交易内：
///         1) 从 V2 借出 token 或 WETH（无需事先提供抵押）
///         2) 在 Uniswap V1 上换成另一侧资产
///         3) 按 V2 恒定乘积（含 0.3% 费）算出应还金额并还给 Pair
///         4) 差额作为套利利润留给发起人
/// @dev 触发方式（本合约本身不暴露入口）：
///      外部调用 `IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data)`，
///      Pair 先把 amount{0,1}Out 转给本合约，再回调 `uniswapV2Call`；回调结束时 Pair 用余额校验 K。
///      仅支持「含 WETH 的 V2 交易对」，且单次只借一侧（即 amount0 或 amount1 为 0）。
contract ExampleFlashSwap is IUniswapV2Callee {
    IUniswapV1Factory immutable factoryV1;
    address immutable factory;
    IWETH immutable WETH;

    constructor(address _factory, address _factoryV1, address router) public {
        factoryV1 = IUniswapV1Factory(_factoryV1);
        factory = _factory;
        WETH = IWETH(IUniswapV2Router01(router).WETH());
    }

    // needs to accept ETH from any V1 exchange and WETH. ideally this could be enforced, as in the router,
    // but it's not possible because it requires a call to the v1 factory, which takes too much gas
    // 接收 V1 兑换吐出的 ETH，以及 WETH.withdraw 解包后的 ETH
    receive() external payable {}

    /// @notice Pair.swap 在乐观转出代币后回调到这里；必须在返回前把「应还资产」转回 Pair。
    /// @param sender 最初调用 pair.swap 的地址（套利利润最终打给它）
    /// @param amount0 Pair 转出的 token0 数量（借 token0 时 >0，否则为 0）
    /// @param amount1 Pair 转出的 token1 数量（借 token1 时 >0，否则为 0）
    /// @param data 发起人编码的滑点下限：借 token 时为 minETH；借 WETH/ETH 时为 minTokens
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
        address[] memory path = new address[](2);
        uint amountToken;
        uint amountETH;
        { // scope for token{0,1}, avoids stack too deep errors
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        // 校验回调方确实是本 factory 下对应的 V2 Pair（防伪造 msg.sender）
        assert(msg.sender == UniswapV2Library.pairFor(factory, token0, token1));
        // 本策略只做单边借入（闪电贷式），不同时借两边
        assert(amount0 == 0 || amount1 == 0);
        // path: [要还给 Pair 的资产, 借出的资产]
        // 例：借了 token1 → path = [token0, token1]，后面 getAmountsIn 求「还多少 token0 才能换回借出的 token1」
        path[0] = amount0 == 0 ? token0 : token1;
        path[1] = amount0 == 0 ? token1 : token0;
        // 把借出量拆成「ERC20 token 侧」与「WETH/ETH 侧」（另一侧为 0）
        amountToken = token0 == address(WETH) ? amount1 : amount0;
        amountETH = token0 == address(WETH) ? amount0 : amount1;
        }

        // 本示例只套利 WETH 对（V1 上 token↔ETH）
        assert(path[0] == address(WETH) || path[1] == address(WETH));
        IERC20 token = IERC20(path[0] == address(WETH) ? path[1] : path[0]);
        IUniswapV1Exchange exchangeV1 = IUniswapV1Exchange(factoryV1.getExchange(address(token))); // get V1 exchange

        if (amountToken > 0) {
            // ========== 分支 A：从 V2 借出 ERC20 token ==========
            // 流程：V2 借 token → V1 卖成 ETH → 部分 ETH 包装成 WETH 还给 V2 → 剩余 ETH 利润给 sender
            (uint minETH) = abi.decode(data, (uint)); // slippage parameter for V1, passed in by caller
            token.approve(address(exchangeV1), amountToken);
            // 在 V1 上把借来的全部 token 换成 ETH
            uint amountReceived = exchangeV1.tokenToEthSwapInput(amountToken, minETH, uint(-1));
            // 反推：要在 V2 上「用 path[0](WETH) 换回刚借出的 amountToken」，需要多少 WETH（含 0.3% 费）
            uint amountRequired = UniswapV2Library.getAmountsIn(factory, amountToken, path)[0];
            assert(amountReceived > amountRequired); // fail if we didn't get enough ETH back to repay our flash loan
            // 把应还部分 ETH 打成 WETH，转回 V2 Pair；Pair 回调返回后会用余额校验 K
            WETH.deposit{value: amountRequired}();
            assert(WETH.transfer(msg.sender, amountRequired)); // return WETH to V2 pair
            // 多出来的 ETH 就是套利利润，打给最初的 swap 发起人
            (bool success,) = sender.call{value: amountReceived - amountRequired}(new bytes(0));
            assert(success);
        } else {
            // ========== 分支 B：从 V2 借出 WETH ==========
            // 流程：V2 借 WETH → unwrap 成 ETH → V1 买 token → 部分 token 还给 V2 → 剩余 token 利润给 sender
            (uint minTokens) = abi.decode(data, (uint)); // slippage parameter for V1, passed in by caller
            WETH.withdraw(amountETH);
            // 在 V1 上用借来的全部 ETH 换成 token
            uint amountReceived = exchangeV1.ethToTokenSwapInput{value: amountETH}(minTokens, uint(-1));
            // 反推：要在 V2 上「用 path[0](token) 换回刚借出的 amountETH(WETH)」，需要多少 token（含费）
            uint amountRequired = UniswapV2Library.getAmountsIn(factory, amountETH, path)[0];
            assert(amountReceived > amountRequired); // fail if we didn't get enough tokens back to repay our flash loan
            assert(token.transfer(msg.sender, amountRequired)); // return tokens to V2 pair
            assert(token.transfer(sender, amountReceived - amountRequired)); // keep the rest! (tokens)
        }
    }
}
