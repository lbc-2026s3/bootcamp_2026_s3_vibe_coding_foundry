// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {CounterV2} from "../../../src/upgradeable/beacon_proxy/CounterV2.sol";
import {CounterBeaconFactory} from "../../../src/upgradeable/beacon_proxy/CounterBeaconFactory.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice 将已部署的 CounterBeaconFactory 升级到 CounterV2（一次 upgradeTo，全部 BeaconProxy 生效）。
/// @dev factory 地址优先读环境变量 `FACTORY`；未设置则读
///      `deployments/CounterBeaconFactory/CounterBeaconFactory_<chainId>.json`
contract CounterV2Script is BaseScript {
    CounterBeaconFactory public factory;
    address public implementationV2;

    function run() public broadcaster {
        factory = CounterBeaconFactory(_resolveFactory());

        CounterV2 v2 = new CounterV2();
        implementationV2 = address(v2);
        factory.upgradeTo(implementationV2);

        // factory / beacon / proxy 地址不变；刷新 LATEST 与新 implementation 记录
        saveContract("CounterBeaconFactory", address(factory));
        saveContract("Counter_UpgradeableBeacon", address(factory.beacon()));
        saveContract("Counter_Implementation", factory.beacon().implementation());

        address proxyC = factory.createCounter(222);
        saveContract("Counter_BeaconProxyC", proxyC);
    }

    function _resolveFactory() internal view returns (address) {
        try vm.envAddress("FACTORY") returns (address fromEnv) {
            return fromEnv;
        } catch {
            string memory path = string.concat(
                "deployments/CounterBeaconFactory/CounterBeaconFactory_",
                vm.toString(block.chainid),
                ".json"
            );
            return vm.parseJsonAddress(vm.readFile(path), ".address");
        }
    }
}
