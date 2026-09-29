// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PredictionMarket} from "./PredictionMarket.sol";

/// @notice 无许可创建二元预测市场。
contract PredictionMarketFactory {
    address[] public markets;

    event MarketCreated(
        address indexed market,
        address indexed creator,
        address collateral,
        uint256 deadline,
        address oracle,
        string question
    );

    function marketCount() external view returns (uint256) {
        return markets.length;
    }

    /// @notice 创建市场；`oracle` 为 0 时使用调用者。
    function createMarket(
        string calldata question,
        address collateral,
        uint256 deadline,
        address oracle
    ) external returns (address market) {
        if (oracle == address(0)) oracle = msg.sender;
        PredictionMarket m = new PredictionMarket(question, collateral, deadline, oracle);
        market = address(m);
        markets.push(market);
        emit MarketCreated(market, msg.sender, collateral, deadline, oracle, question);
    }
}
