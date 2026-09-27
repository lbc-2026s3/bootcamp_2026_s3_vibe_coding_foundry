// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// RebaseToken — 每年通缩 1% 的 rebase ERC20
// 初始 100 万枚铸给部署者；满一年后任何人可调用 rebase()。
//
// forge script script/rebase/DeployRebaseToken.s.sol:DeployRebaseToken \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {RebaseToken} from "../../src/rebase/RebaseToken.sol";

contract DeployRebaseToken is BaseScript {
    RebaseToken public token;

    function run() public broadcaster {
        token = new RebaseToken(deployer);

        saveContract("RebaseToken", address(token));

        console.log("RebaseToken:      ", address(token));
        console.log("recipient:        ", deployer);
        console.log("initial supply:   ", token.totalSupply());
        console.log("next rebase at:   ", token.nextRebaseTimestamp());
    }
}
