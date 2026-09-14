// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MemeFactory} from "../src/MemeFactory.sol";
import {BaseScript} from "./BaseScript.s.sol";

contract MemeFactoryScript is BaseScript {
    MemeFactory public factory;

    function run() public broadcaster {
        factory = new MemeFactory();
        saveContract("MemeFactory", address(factory));
        saveContract("MemeTokenImplementation", factory.implementation());
    }
}
