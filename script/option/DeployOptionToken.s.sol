// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// OptionToken — ETH 看涨期权 ERC20
//
// 环境变量（可选）：
//   USDT         — 行权支付代币；未设则部署 MockUSDT(6 decimals)
//   STRIKE_PRICE — USDT 最小单位 / 1 ETH，默认 2000e6
//   EXPIRY       — 到期日起始 unix；默认 now + 30 days
//
// forge script script/option/DeployOptionToken.s.sol:DeployOptionToken \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {OptionToken} from "../../src/option/OptionToken.sol";

contract DeployMockUSDT is ERC20 {
    constructor() ERC20("Tether USD", "USDT") {
        _mint(msg.sender, 1_000_000_000e6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract DeployOptionToken is BaseScript {
    OptionToken public option;
    address public usdt;

    function run() public broadcaster {
        usdt = vm.envOr("USDT", address(0));
        if (usdt == address(0)) {
            DeployMockUSDT mock = new DeployMockUSDT();
            usdt = address(mock);
            saveContract("MockUSDT", usdt);
            console.log("MockUSDT:         ", usdt);
        }

        // STRIKE_PRICE: 行权价，单位为 USDT 最小单位 / 1 ETH。
        //   默认 2000e6 = 2000 USDT（6 decimals）兑换 1 ETH。
        uint256 strikePrice = vm.envOr("STRIKE_PRICE", uint256(2000e6));
        // EXPIRY: 到期日起始 unix 时间戳；行权窗口为 [EXPIRY, EXPIRY+1 days)。
        //   默认部署时刻起 30 天后。
        uint256 expiry = vm.envOr("EXPIRY", uint256(block.timestamp + 30 days));

        option = new OptionToken("ETH Call Option", "oETH", usdt, strikePrice, expiry, deployer);

        saveContract("OptionToken", address(option));

        console.log("OptionToken:      ", address(option));
        console.log("usdt:             ", usdt);
        console.log("strikePrice:      ", strikePrice);
        console.log("expiry:           ", expiry);
        console.log("exerciseDeadline: ", option.exerciseDeadline());
    }
}
