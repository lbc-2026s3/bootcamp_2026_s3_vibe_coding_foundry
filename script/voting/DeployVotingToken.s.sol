// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// VotingToken — OpenZeppelin ERC20Votes 治理代币
//
// 环境变量（可选）：
//   NAME           — Token 名称，默认 "Vote Token"
//   SYMBOL         — Token 符号，默认 "VOTE"
//   INITIAL_SUPPLY — 部署时铸给 deployer 的数量，默认 1_000_000e18
//
// forge script script/voting/DeployVotingToken.s.sol:DeployVotingToken \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {VotingToken} from "../../src/voting/VotingToken.sol";

contract DeployVotingToken is BaseScript {
    VotingToken public token;

    function run() public broadcaster {
        string memory name_ = vm.envOr("NAME", string("Vote Token"));
        string memory symbol_ = vm.envOr("SYMBOL", string("VOTE"));
        uint256 initialSupply = vm.envOr("INITIAL_SUPPLY", uint256(1_000_000e18));

        token = new VotingToken(name_, symbol_, deployer, initialSupply);

        // ERC20Votes 默认「持币 ≠ 有票」：未调用 delegate 时 getVotes 为 0。
        //
        // delegate(地址) = 把「调用者余额」对应的票权交给该地址（整账户、不能拆分）：
        //   - delegate(自己)  → 自委托：票权记在自己名下（本脚本做法）
        //   - delegate(他人)  → 票权给对方，自己 getVotes 变 0（除非别人又委托给你）
        // 例：有 100 币不能「60 给别人、40 留给自己」；要拆只能先把币转到多个地址再各自 delegate。
        // 这里给 deployer 自委托，教学演示里部署后立刻有投票权；生产可省略，由持有人自行开启。
        token.delegate(deployer);

        saveContract("VotingToken", address(token));

        console.log("VotingToken: ", address(token));
        console.log("name:        ", name_);
        console.log("symbol:      ", symbol_);
        console.log("supply:      ", initialSupply);
        console.log("votes:       ", token.getVotes(deployer));
    }
}
