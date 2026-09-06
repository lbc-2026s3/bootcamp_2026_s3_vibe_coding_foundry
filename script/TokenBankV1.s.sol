// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MyTokenV1} from "../src/MyTokenV1.sol";
import {TokenBankV1} from "../src/TokenBankV1.sol";
import {BaseScript} from "./BaseScript.sol";

contract TokenBankV1Script is BaseScript {
    MyTokenV1 public token;
    TokenBankV1 public bank;

    function run() public broadcaster {
        // 先部署 MyTokenV1(100 万枚 MT 铸给部署者),再部署 TokenBankV1
        token = new MyTokenV1();
        bank = new TokenBankV1(token);
        saveContract("MyTokenV1", address(token));
        saveContract("TokenBankV1", address(bank));
    }
}
