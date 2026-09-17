// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/Script.sol";
import {Counter} from "../../src/mini_proxy/Counter.sol";
import {CounterCloneFactory} from "../../src/mini_proxy/CounterCloneFactory.sol";
import {BaseScript} from "../BaseScript.s.sol";

/// @notice 部署 CounterCloneFactory（内含一份 Counter impl），再克隆两份最小代理做演示。
contract CounterCloneFactoryScript is BaseScript {
    uint256 public constant INITIAL_NUMBER_A = 0;
    uint256 public constant INITIAL_NUMBER_B = 100;

    CounterCloneFactory public factory;
    address public proxyA;
    address public proxyB;

    function run() public broadcaster {
        factory = new CounterCloneFactory();
        proxyA = factory.createCounter(INITIAL_NUMBER_A);
        proxyB = factory.createCounter(INITIAL_NUMBER_B);

        console.log("CounterCloneFactory", address(factory));
        console.log("Counter implementation", factory.implementation());
        console.log("Counter proxy A", proxyA);
        console.log("Counter proxy B", proxyB);
        console.log("proxy A number", Counter(proxyA).number());
        console.log("proxy B number", Counter(proxyB).number());

        saveContract("CounterCloneFactory", address(factory));
        saveContract("Counter_Implementation", factory.implementation());
        saveContract("Counter_ProxyA", proxyA);
        saveContract("Counter_ProxyB", proxyB);
    }
}
