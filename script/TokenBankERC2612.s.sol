// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyTokenERC2612Permit} from "../src/MyTokenERC2612Permit.sol";
import {TokenBankERC2612} from "../src/TokenBankERC2612.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyTokenERC2612Permit + TokenBankERC2612
contract TokenBankERC2612Script is BaseScript {
    MyTokenERC2612Permit public token;
    TokenBankERC2612 public bank;

    function run() public broadcaster {
        token = new MyTokenERC2612Permit();
        bank = new TokenBankERC2612(token);
        saveContract("MyTokenERC2612Permit", address(token));
        saveContract("TokenBankERC2612", address(bank));
    }
}
