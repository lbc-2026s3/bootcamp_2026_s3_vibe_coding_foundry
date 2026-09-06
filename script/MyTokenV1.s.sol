// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MyTokenV1} from "../src/MyTokenV1.sol";
import {BaseScript} from "./BaseScript.sol";

contract MyTokenV1Script is BaseScript {
    MyTokenV1 public token;

    function run() public broadcaster {
        token = new MyTokenV1();
        saveContract("MyTokenV1", address(token));
    }
}
