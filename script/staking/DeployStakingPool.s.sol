// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// StakingPool — ETH 质押挖矿
// 每区块铸造 10 KK，按质押 ETH 数量占比分配。
// 用户可随时 claim() 领 KK，或 withdraw() 取回本金（取本金时一并结算奖励）。
//
// forge script script/staking/DeployStakingPool.s.sol:DeployStakingPool \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {StakingPool} from "../../src/staking/StakingPool.sol";

contract DeployStakingPool is BaseScript {
    StakingPool public pool;

    function run() public broadcaster {
        pool = new StakingPool();
        saveContract("StakingPool", address(pool));
        saveContract("KKToken", address(pool.kkToken()));

        console.log("StakingPool:     ", address(pool));
        console.log("KKToken:         ", address(pool.kkToken()));
        console.log("reward per block:", pool.REWARD_PER_BLOCK());
        console.log("start block:     ", pool.lastRewardBlock());
    }
}
