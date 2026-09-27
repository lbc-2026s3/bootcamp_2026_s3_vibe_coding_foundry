// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice 教学预言机。价格是 1 个代币值多少美元，18 位小数。部署者可改价。
contract SimplePriceOracle is Ownable {
    mapping(address asset => uint256 price) public prices;

    error ZeroPrice();

    event PriceSet(address indexed asset, uint256 price);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice 设置 asset 的美元价格。
    function setPrice(address asset, uint256 price) external onlyOwner {
        if (price == 0) revert ZeroPrice();
        prices[asset] = price;
        emit PriceSet(asset, price);
    }

    /// @notice 返回价格。没设过则为 0。
    function getPrice(address asset) external view returns (uint256) {
        return prices[asset];
    }
}
