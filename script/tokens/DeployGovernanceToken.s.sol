// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// GovernanceToken — ERC20Votes 治理代币，自带提案 / 投票 / 标记执行
//
// 部署后会给 deployer 自委托。本块刚委托的票要到下一块才能用来 `propose`
// （门槛看的是上一块的 getPastVotes）。
//
// forge script script/tokens/DeployGovernanceToken.s.sol:DeployGovernanceToken \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {GovernanceToken} from "../../src/tokens/GovernanceToken.sol";

contract DeployGovernanceToken is BaseScript {
    GovernanceToken public token;

    function run() public broadcaster {
        token = new GovernanceToken();
        token.delegate(deployer);

        saveContract("GovernanceToken", address(token));

        console.log("GovernanceToken: ", address(token));
        console.log("name:             ", token.name());
        console.log("symbol:           ", token.symbol());
        console.log("supply:           ", token.totalSupply());
        console.log("votes:            ", token.getVotes(deployer));
    }
}
