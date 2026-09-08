// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IGreeter} from "./IGreeter.sol";

/// @notice 反例:实现了 IGreeter 行为,但没有 ERC-165,外部无法安全探测
contract GreeterNo165 is IGreeter {
    string private _greeting;

    constructor(string memory greeting_) {
        _greeting = greeting_;
    }

    function greet() external view override returns (string memory) {
        return _greeting;
    }

    function setGreeting(string calldata newGreeting) external override {
        _greeting = newGreeting;
    }
}
