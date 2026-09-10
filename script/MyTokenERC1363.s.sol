// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyTokenERC1363} from "../src/MyTokenERC1363.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 单独部署 MyTokenERC1363；构造函数会给部署人铸造 100 万枚（18 位小数）
contract MyTokenERC1363Script is BaseScript {
    MyTokenERC1363 public token;

    function run() public broadcaster {
        token = new MyTokenERC1363();
        saveContract("MyTokenERC1363", address(token));
    }
}
