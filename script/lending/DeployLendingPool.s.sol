// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// LendingPool — 教学借贷池
// 部署 WETH、USDC、预言机、Jump Rate 和资金池。
//
// forge script script/lending/DeployLendingPool.s.sol:DeployLendingPool \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {MockERC20} from "../../src/lending/MockERC20.sol";
import {JumpRateModel} from "../../src/lending/JumpRateModel.sol";
import {SimplePriceOracle} from "../../src/lending/SimplePriceOracle.sol";
import {LendingPool} from "../../src/lending/LendingPool.sol";

contract DeployLendingPool is BaseScript {
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    function run() public broadcaster {
        MockERC20 weth = new MockERC20("Wrapped Ether", "WETH");
        MockERC20 usdc = new MockERC20("USD Coin", "USDC");

        SimplePriceOracle oracle = new SimplePriceOracle(deployer);
        oracle.setPrice(address(weth), 2000e18);
        oracle.setPrice(address(usdc), 1e18);

        // 模型存的是每秒利率。0.02e18 表示年化 2%（1e18 = 100%），除以一年的秒数才得到每秒值。
        // 利用率 ≤ 80%：年化 = 2% + 利用率 × 10%。正好 80% 时是 2% + 8% = 10%。
        // 利用率 > 80%：超出的部分改用 450% 的斜率。到 100% 时再加 20% × 450% = 90%，借款年化变成 100%。
        JumpRateModel model = new JumpRateModel({
            baseRatePerSecond_: 0.02e18 / SECONDS_PER_YEAR, // 利用率接近 0 时的借款底息，年化 2%。总债务为 0 时利息仍是 0
            multiplierPerSecond_: 0.10e18 / SECONDS_PER_YEAR, // 拐点以下的斜率：年化再加上「利用率 × 10%」。50% 时加 5%，到 80% 时加 8%
            jumpMultiplierPerSecond_: 4.5e18 / SECONDS_PER_YEAR, // 拐点以上只对超出 80% 的部分乘 450%。从 80% 到 100% 再加 20% × 450% = 90%
            kink_: 0.80e18 // 拐点。利用率 80%，1e18 = 100%
        });

        LendingPool pool = new LendingPool(
            weth, usdc, oracle, model, 0.75e18, 1.08e18, 0.50e18, 0.10e18, deployer
        );

        saveContract("WETH", address(weth));
        saveContract("USDC", address(usdc));
        saveContract("SimplePriceOracle", address(oracle));
        saveContract("JumpRateModel", address(model));
        saveContract("LendingPool", address(pool));

        console.log("WETH:            ", address(weth));
        console.log("USDC:            ", address(usdc));
        console.log("SimplePriceOracle", address(oracle));
        console.log("JumpRateModel:   ", address(model));
        console.log("LendingPool:     ", address(pool));
    }
}
