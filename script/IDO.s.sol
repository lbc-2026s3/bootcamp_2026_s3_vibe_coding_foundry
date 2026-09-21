// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MyTokenV1} from "../src/MyTokenV1.sol";
import {IDO} from "../src/IDO.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyTokenV1（100 万枚 OPS）+ IDO，并把全部 token 转入 IDO 供 claim。
/// @dev 环境变量：
///   IDO_DURATION — 可选，预售时长（秒），默认 7 days
/// @dev forge script script/IDO.s.sol:IDOScript --broadcast --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
contract IDOScript is BaseScript {
    uint256 internal constant DEFAULT_DURATION = 7 days;

    MyTokenV1 public token;
    IDO public ido;

    function run() public broadcaster {
        uint256 duration = vm.envOr("IDO_DURATION", DEFAULT_DURATION);

        token = new MyTokenV1();
        ido = new IDO(address(token), duration);
        token.transfer(address(ido), token.INITIAL_SUPPLY());

        saveContract("MyTokenV1", address(token));
        saveContract("IDO", address(ido));
    }
}
