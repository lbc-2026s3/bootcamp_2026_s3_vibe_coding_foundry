// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";
import {TokenBankV1} from "../src/TokenBankV1.sol";

contract TokenBankV1Script is Script {
    MyTokenV1 public token;
    TokenBankV1 public bank;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 先部署 MyTokenV1(100 万枚 MT 铸给部署者),再部署 TokenBankV1
        token = new MyTokenV1();
        bank = new TokenBankV1(token);

        vm.stopBroadcast();
    }
}
