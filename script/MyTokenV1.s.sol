// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";

contract MyTokenV1Script is Script {
    MyTokenV1 public token;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new MyTokenV1();

        vm.stopBroadcast();
    }
}
