// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";
import {Create3Factory} from "../src/Create3Factory.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 先部署 Create3Factory,再用 Solmate CREATE3 部署 Counter
/// @dev CREATE3 地址 = f(factory, salt),与 Counter 的 creationCode / 构造参数无关
contract CounterCreate3Script is BaseScript {
    bytes32 public constant SALT = keccak256("lbc-2026s3:Counter");
    uint256 public constant INITIAL_NUMBER = 0;

    Create3Factory public factory;
    Counter public counter;

    function run() public broadcaster {
        factory = new Create3Factory();

        bytes memory creationCode = abi.encodePacked(type(Counter).creationCode, abi.encode(INITIAL_NUMBER));
        address predicted = factory.getDeployed(SALT);
        address deployed = factory.deploy(SALT, creationCode);
        require(deployed == predicted, "CREATE3 address mismatch");

        counter = Counter(deployed);
        require(counter.number() == INITIAL_NUMBER, "Counter init mismatch");

        console.log("Create3Factory", address(factory));
        console.log("Counter (CREATE3)", deployed);
        console.log("predicted Counter", predicted);

        saveContract("Create3Factory", address(factory));
        saveContract("Counter", deployed);
    }
}
