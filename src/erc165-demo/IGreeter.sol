// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice 教学用接口:演示 ERC-165 interfaceId 如何由函数 selector XOR 得到
interface IGreeter {
    function greet() external view returns (string memory);
    function setGreeting(string calldata newGreeting) external;
}
