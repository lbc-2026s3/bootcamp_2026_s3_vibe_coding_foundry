// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {UniswapV2Factory} from "../../uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../../uniswapv2/UniswapV2Router02.sol";
import {WETH9} from "../../uniswapv2/WETH9.sol";
import {MyTokenV1} from "../../src/MyTokenV1.sol";

/// @notice 部署 Uniswap V2 Factory + WETH9 + Router02，可选部署演示代币并加初始流动性
/// @dev 环境变量(全部可选):
///   UNIV2_FEE_TO_SETTER — Factory feeToSetter，默认广播账户
///   UNIV2_WETH          — 已有 WETH 地址；留空则部署 WETH9
///   UNIV2_SEED_LIQUIDITY — 设为 1 时部署两个 MyTokenV1 并注入流动性
///   UNIV2_SEED_AMOUNT    — 每种代币注入数量(wei)，默认 100000e18
/// @dev forge script script/uniswapv2/DeployUniswapV2.s.sol:DeployUniswapV2 \
///        --broadcast --rpc-url local && cat ./deployments/LATEST.txt
contract DeployUniswapV2 is BaseScript {
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    WETH9 public weth;

    function run() public broadcaster {
        address feeToSetter = vm.envOr("UNIV2_FEE_TO_SETTER", deployer);

        address existingWeth = vm.envOr("UNIV2_WETH", address(0));
        if (existingWeth != address(0)) {
            weth = WETH9(payable(existingWeth));
            saveContract("WETH9", existingWeth);
        } else {
            weth = new WETH9();
            saveContract("WETH9", address(weth));
        }

        factory = new UniswapV2Factory(feeToSetter);
        saveContract("UniswapV2Factory", address(factory));

        router = new UniswapV2Router02(address(factory), address(weth));
        saveContract("UniswapV2Router02", address(router));

        console.log("Factory:", address(factory));
        console.log("WETH:   ", address(weth));
        console.log("Router: ", address(router));

        uint256 seedFlag = vm.envOr("UNIV2_SEED_LIQUIDITY", uint256(0));
        if (seedFlag != 0) {
            uint256 seedAmount = vm.envOr("UNIV2_SEED_AMOUNT", uint256(100_000e18));
            MyTokenV1 tokenA = new MyTokenV1();
            MyTokenV1 tokenB = new MyTokenV1();
            saveContract("UniV2DemoTokenA", address(tokenA));
            saveContract("UniV2DemoTokenB", address(tokenB));

            tokenA.approve(address(router), seedAmount);
            tokenB.approve(address(router), seedAmount);
            router.addLiquidity(
                address(tokenA),
                address(tokenB),
                seedAmount,
                seedAmount,
                0,
                0,
                deployer,
                block.timestamp + 1 hours
            );
            address pair = factory.getPair(address(tokenA), address(tokenB));
            saveContract("UniV2DemoPair", pair);
            console.log("Seeded pair:", pair);
        }
    }
}
