// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// DAOVoting — EIP-712 离线签名计票
//
// 合约无构造参数。domain name = "DAOVoting"，version = "1"。
//
// forge script script/eip-712/DeployDAOVoting.s.sol:DeployDAOVoting \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {DAOVoting} from "../../src/eip-712/DAOVoting.sol";

contract DeployDAOVoting is BaseScript {
    DAOVoting public voting;

    function run() public broadcaster {
        voting = new DAOVoting();

        saveContract("DAOVoting", address(voting));

        console.log("DAOVoting:", address(voting));
        console.log("name:     ", voting.NAME());
        console.log("version:  ", voting.VERSION());
    }
}
