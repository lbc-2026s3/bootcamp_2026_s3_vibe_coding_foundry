// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {CounterBeaconFactory} from "../../../src/upgradeable/beacon_proxy/CounterBeaconFactory.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice 部署 CounterBeaconFactory（V1 impl + Beacon），并创建两份 BeaconProxy。
contract CounterBeaconFactoryScript is BaseScript {
    uint256 public constant INITIAL_NUMBER_A = 0;
    uint256 public constant INITIAL_NUMBER_B = 100;

    CounterBeaconFactory public factory;
    address public proxyA;
    address public proxyB;

    function run() public broadcaster {
        factory = new CounterBeaconFactory(deployer);
        proxyA = factory.createCounter(INITIAL_NUMBER_A);
        proxyB = factory.createCounter(INITIAL_NUMBER_B);

        saveContract("CounterBeaconFactory", address(factory));
        saveContract("Counter_UpgradeableBeacon", address(factory.beacon()));
        saveContract("Counter_Implementation", factory.beacon().implementation());
        saveContract("Counter_BeaconProxyA", proxyA);
        saveContract("Counter_BeaconProxyB", proxyB);
    }
}
