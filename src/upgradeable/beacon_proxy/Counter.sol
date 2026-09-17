// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @notice Counter 逻辑实现，配合 BeaconProxy + UpgradeableBeacon 使用。
/// @dev 升级权在 beacon 上，本合约不继承 UUPS。构造函数只锁住实现合约自身的 initialize。
contract Counter is Initializable {
    uint256 public number;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice 由 BeaconProxy 构造时的 initializer data 写入该代理自己的初始值。
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
