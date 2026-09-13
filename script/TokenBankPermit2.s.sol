// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";
import {TokenBankPermit2} from "../src/TokenBankPermit2.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyTokenV1 + TokenBankPermit2(绑定链上/同址 Permit2)
/// @dev 主网 / Sepolia / 多数 L2 上 Permit2 地址相同(CREATE2)
contract TokenBankPermit2Script is BaseScript {
    /// @dev https://etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    MyTokenV1 public token;
    TokenBankPermit2 public bank;

    function run() public broadcaster {
        require(PERMIT2.code.length > 0, "Permit2 not deployed on this chain");

        token = new MyTokenV1();
        bank = new TokenBankPermit2(token, ISignatureTransfer(PERMIT2));
        saveContract("MyTokenV1", address(token));
        saveContract("TokenBankPermit2", address(bank));
    }
}
