// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";
import {MiniSwapPool} from "../src/MiniSwapPool.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MiniSwapPool(极简 x*y=k AMM 池)及其底层的两个 ERC20 代币,可选地由部署人注入初始流动性。
/// @dev 环境变量(全部可选):
///   MINISWAP_TOKEN0     — 已有 token0 地址;留空则新部署一个 MyTokenV1
///   MINISWAP_TOKEN1     — 已有 token1 地址;留空则新部署一个 MyTokenV1
///   MINISWAP_LP_NAME    — LP 代币名称,默认 "MiniSwapPool"
///   MINISWAP_LP_SYMBOL  — LP 代币符号,默认 "MSP"
///   MINISWAP_SEED_AMOUNT0 — 初始注入 token0 数量(wei);留空则不注入流动性
///   MINISWAP_SEED_AMOUNT1 — 初始注入 token1 数量(wei);留空则不注入流动性
/// @dev forge script script/MiniSwapPool.s.sol:MiniSwapPoolScript --broadcast --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
contract MiniSwapPoolScript is BaseScript {
    string internal constant DEFAULT_LP_NAME = "MiniSwapPool";
    string internal constant DEFAULT_LP_SYMBOL = "MSP";

    MyTokenV1 public token0;
    MyTokenV1 public token1;
    MiniSwapPool public pool;

    function run() public broadcaster {
        string memory lpName = vm.envOr("MINISWAP_LP_NAME", DEFAULT_LP_NAME);
        string memory lpSymbol = vm.envOr("MINISWAP_LP_SYMBOL", DEFAULT_LP_SYMBOL);

        address existingToken0 = vm.envOr("MINISWAP_TOKEN0", address(0));
        address existingToken1 = vm.envOr("MINISWAP_TOKEN1", address(0));

        // token0: 复用已有地址或新部署
        if (existingToken0 != address(0)) {
            token0 = MyTokenV1(existingToken0);
            saveContract("MiniSwapToken0", existingToken0);
        } else {
            token0 = new MyTokenV1();
            saveContract("MiniSwapToken0", address(token0));
        }

        // token1: 复用已有地址或新部署
        if (existingToken1 != address(0)) {
            token1 = MyTokenV1(existingToken1);
            saveContract("MiniSwapToken1", existingToken1);
        } else {
            token1 = new MyTokenV1();
            saveContract("MiniSwapToken1", address(token1));
        }

        pool = new MiniSwapPool(
            address(token0),
            address(token1),
            lpName,
            lpSymbol
        );
        saveContract("MiniSwapPool", address(pool));

        // 可选:由部署人注入初始流动性(需先 approve 给 pool)
        uint256 seedAmount0 = vm.envOr("MINISWAP_SEED_AMOUNT0", uint256(0));
        uint256 seedAmount1 = vm.envOr("MINISWAP_SEED_AMOUNT1", uint256(0));
        if (seedAmount0 > 0 && seedAmount1 > 0) {
            // 仅当 token 是本次新部署时,部署人才有余额可直接 approve;
            // 若复用已有 token,需部署人事先自行 approve,这里仅尝试调用,失败由上层处理
            token0.approve(address(pool), seedAmount0);
            token1.approve(address(pool), seedAmount1);
            pool.addLiquidity(seedAmount0, seedAmount1);
            console.log("Seed liquidity added:", seedAmount0, "/", seedAmount1);
        } else {
            console.log("No seed liquidity (set MINISWAP_SEED_AMOUNT0/1 to seed)");
        }
    }
}
