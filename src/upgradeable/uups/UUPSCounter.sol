// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @notice UUPS 计数器 V1。升级函数在实现合约里，经 ERC1967Proxy delegatecall 执行。
/// @dev 升级权 = Ownable owner（存在代理存储中）。实现合约构造时禁用 initializer。
contract UUPSCounter is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public number;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice 由代理构造时的 initializer data 调用，写入该代理自己的初始值与升级权持有人。
    function initialize(uint256 initialNumber, address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        number = initialNumber;
    }

    function increment() public {
        number++;
    }

    /// @notice 逻辑版本，便于升级后从代理读到 V2。
    function version() public pure virtual returns (uint256) {
        return 1;
    }

    /// @dev 只有代理上的 owner 能通过 upgradeToAndCall 换实现。
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
