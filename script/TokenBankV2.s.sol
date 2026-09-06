// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MyTokenV1} from "../src/MyTokenV1.sol";
import {TokenBankV2} from "../src/TokenBankV2.sol";
import {BaseScript} from "./BaseScript.s.sol";

contract TokenBankV2Script is BaseScript {
    MyTokenV1 public token;
    TokenBankV2 public bank;

    function run() public broadcaster {
        // 先部署 MyTokenV1(100 万枚 MT 铸给部署者),再部署 TokenBankV2
        token = new MyTokenV1();
        bank = new TokenBankV2(token);
        saveContract("MyTokenV1", address(token));
        saveContract("TokenBankV2", address(bank));
    }
}
