// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Counter} from "./Counter.sol";

/// @notice 部署一份 Counter impl + UpgradeableBeacon，再创建多个 BeaconProxy。
/// @dev factory 持有 beacon（以便转发 upgradeTo）；Ownable 控制谁能升级。生产环境应将 owner 交给 multisig/timelock。
///      当前实现地址读 `beacon.implementation()`。
contract CounterBeaconFactory is Ownable {
    UpgradeableBeacon public immutable beacon;

    event CounterCreated(address indexed proxy, uint256 initialNumber);
    event ImplementationUpgraded(address indexed newImplementation);

    constructor(address initialOwner) Ownable(initialOwner) {
        address implementation = address(new Counter());
        // beacon 的 owner 必须是本合约，否则外部无法经 factory 转发 upgradeTo
        beacon = new UpgradeableBeacon(implementation, address(this));
    }

    /// @notice 创建一份 BeaconProxy，并在构造时 initialize。
    function createCounter(uint256 initialNumber) external returns (address proxy) {
        bytes memory initData = abi.encodeCall(Counter.initialize, (initialNumber));
        proxy = address(new BeaconProxy(address(beacon), initData));
        emit CounterCreated(proxy, initialNumber);
    }

    /// @notice 升级 beacon 指向的实现；仅 factory owner 可调用。
    function upgradeTo(address newImplementation) external onlyOwner {
        beacon.upgradeTo(newImplementation);
        emit ImplementationUpgraded(newImplementation);
    }
}
