// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @notice Counter 逻辑实现，配合 EIP-1167 最小代理（Clones）使用。
/// @dev 构造函数只锁住实现合约自身的 initialize；每个 clone 通过 initialize 写入各自 storage。
contract Counter is Initializable {
    uint256 public number;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice 由工厂在 clone 部署后调用，写入该代理自己的初始值。
    function initialize(uint256 initialNumber) external initializer {
        number = initialNumber;
    }

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
