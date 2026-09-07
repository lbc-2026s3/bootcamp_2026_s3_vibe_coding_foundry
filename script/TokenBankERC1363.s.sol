// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyTokenERC1363} from "../src/MyTokenERC1363.sol";
import {TokenBankERC1363} from "../src/TokenBankERC1363.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyTokenERC1363 + TokenBankERC1363
contract TokenBankERC1363Script is BaseScript {
    MyTokenERC1363 public token;
    TokenBankERC1363 public bank;

    function run() public broadcaster {
        token = new MyTokenERC1363();
        bank = new TokenBankERC1363(token);
        saveContract("MyTokenERC1363", address(token));
        saveContract("TokenBankERC1363", address(bank));
    }
}
