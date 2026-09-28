// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// SimpleLeverageDEX — 教学用杠杆 DEX（vAMM + USDC 保证金）
// 部署 MockUSDC 与 DEX；初始虚拟储备 1000 ETH / 1_000_000 USDC（价格 1000）。
//
// forge script script/leverage/DeploySimpleLeverageDEX.s.sol:DeploySimpleLeverageDEX \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {MockERC20} from "../../src/lending/MockERC20.sol";
import {SimpleLeverageDEX} from "../../src/leverage/SimpleLeverageDEX.sol";

contract DeploySimpleLeverageDEX is BaseScript {
    uint256 internal constant V_ETH = 1_000 ether;
    uint256 internal constant V_USDC = 1_000_000e18;
    uint256 internal constant INITIAL_MINT = 1_000_000e18;

    function run() public broadcaster {
        MockERC20 usdc = new MockERC20("USD Coin", "USDC");
        SimpleLeverageDEX dex = new SimpleLeverageDEX(V_ETH, V_USDC, address(usdc));

        // 给部署者一些测试用 USDC，方便本地开仓
        usdc.mint(deployer, INITIAL_MINT);

        saveContract("MockUSDC", address(usdc));
        saveContract("SimpleLeverageDEX", address(dex));

        console.log("MockUSDC:         ", address(usdc));
        console.log("SimpleLeverageDEX:", address(dex));
        console.log("vETH:             ", V_ETH);
        console.log("vUSDC:            ", V_USDC);
        console.log("deployer USDC:    ", usdc.balanceOf(deployer));
    }
}
