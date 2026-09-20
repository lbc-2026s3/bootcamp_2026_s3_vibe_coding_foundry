// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseScript} from "../BaseScript.s.sol";
import {PriceConsumer} from "../../src/chainlink_pricefeed/PriceConsumer.sol";

/// @notice 部署 PriceConsumer 到目标链（默认 Sepolia ETH/USD Data Feed）。
/// @dev 环境变量：
///   PRICE_FEED       — 可选，默认 Sepolia ETH/USD `0x694AA1769357215DE4FAC081bf1f309aDC325306`
///   PRICE_HEARTBEAT  — 可选，默认 24 hours（testnet feed 可能比主网更慢）
/// @dev forge script script/chainlink_pricefeed/DeployPriceConsumer.s.sol --broadcast --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
contract DeployPriceConsumerScript is BaseScript {
    // https://docs.chain.link/data-feeds/api-reference
    address internal constant SEPOLIA_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    uint256 internal constant DEFAULT_HEARTBEAT = 24 hours;

    function run() public broadcaster {
        address feed = vm.envOr("PRICE_FEED", SEPOLIA_ETH_USD);
        uint256 heartbeat = vm.envOr("PRICE_HEARTBEAT", DEFAULT_HEARTBEAT);

        // heartbeat：允许的最大价格年龄（秒）。Chainlink DON 按「时间间隔或价格偏差」更新 feed；
        // 若 latestRoundData.updatedAt 距现在超过 heartbeat，getLatestPrice 会 StalePrice revert，拒绝用过期价。
        // 主网 ETH/USD 官方 heartbeat 约 3600s；Sepolia 更新更慢，这里默认 24 hours。
        PriceConsumer consumer = new PriceConsumer(feed, heartbeat);
        saveContract("PriceConsumer", address(consumer));
    }
}
