// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @notice 透明代理计数器 V1。本合约没有升级函数。
/// @dev 升级权在代理部署时创建的 ProxyAdmin 上，不在实现合约里。
///      构造函数只锁住实现合约自身的 initialize，避免别人直接初始化实现。
contract TransparentCounter is Initializable {
    uint256 public number;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice 由 TransparentUpgradeableProxy 构造时的 initializer data 写入该代理自己的初始值。
    function initialize(uint256 initialNumber) external initializer {
        number = initialNumber;
    }

    function increment() public {
        number++;
    }

    /// @notice 逻辑版本，便于升级后从代理读到 V2。
    function version() public pure virtual returns (uint256) {
        return 1;
    }
}
