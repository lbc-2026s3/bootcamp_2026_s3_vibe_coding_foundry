// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyTokenERC2612Permit} from "../src/MyTokenERC2612Permit.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 单独部署 MyTokenERC2612Permit；构造函数会给部署人铸造 100 万枚（18 位小数）
contract MyTokenERC2612PermitScript is BaseScript {
    MyTokenERC2612Permit public token;

    function run() public broadcaster {
        token = new MyTokenERC2612Permit();
        saveContract("MyTokenERC2612Permit", address(token));
    }
}
