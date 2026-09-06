// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {ETHBank} from "../src/ETHBank.sol";

contract ETHBankScript is Script {
    ETHBank public bank;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        bank = new ETHBank();

        vm.stopBroadcast();
    }
}
