// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// DAO — DAOToken + TimelockController + DAOGov + DAOBank
//
// 部署顺序：Token → Timelock → Gov → 授予角色 → Bank(owner=Timelock)
// deployer 持有初始供给并自委托，便于本地立刻发起/投票提案。
//
// ---------------------------------------------------------------------------
// 投票原理（OpenZeppelin Governor + ERC20Votes + Timelock）
//
// 1) 票权来自 Token，不来自余额本身
//    - 持有 DAOToken ≠ 有票。必须 token.delegate(自己或他人) 后，被委托者 getVotes 才 > 0。
//    - 票权按账户整笔委托，不能拆成「一部分给 A、一部分留给自己」。
//
// 2) 提案时拍快照，投票用历史票权
//    - propose 时记录 snapshot 区块；之后再买币/委托，不影响本次提案的票数。
//    - castVote 读的是 getPastVotes(voter, snapshot)，防闪电贷刷票。
//
// 3) 提案生命周期（含 Timelock 延迟执行）
//    Pending --votingDelay--> Active --投票结束--> Succeeded / Defeated
//      ↑                        ↑                     ↓（仅 Succeeded）
//   propose                  castVote               queue
//                                                     ↓ 等 minDelay（如 2 days）
//                                                  execute
//
//    - Pending：刚创建，不能投票。
//    - Active：可 castVote；support = 0 Against / 1 For / 2 Abstain。
//    - Succeeded：For > Against，且 (For + Abstain) ≥ quorum → 须 queue。
//    - Queued：已进入 Timelock，未到 ETA 前不能 execute。
//    - Defeated：反对占优，或法定人数未达。
//    - execute：由 Timelock（Bank owner）真正调用目标（如 bank.withdraw）。
//
// 4) 法定人数 quorum
//    - quorum = 快照时总供给 × QUORUM_NUMERATOR / 100（默认 4%）。
//    - CountingSimple：For + Abstain 计入 quorum；通过还需 For 严格大于 Against。
//
// 5) 提款示例（治理管资金）
//    targets  = [DAOBank]
//    values   = [0]
//    calldatas = [abi.encodeCall(DAOBank.withdraw, (recipient, amount))]
//    → propose → 等 delay → castVote(For) → 等 period → queue → 等 minDelay → execute
//
// 环境变量（可选）：
//   NAME                — Token 名称，默认 "DAO Token"
//   SYMBOL              — Token 符号，默认 "DAO"
//   INITIAL_SUPPLY      — 铸给 deployer 的数量，默认 1_000_000e18
//   VOTING_DELAY        — 提案后到开票的区块数，默认 1
//   VOTING_PERIOD       — 投票持续区块数，默认 14
//   PROPOSAL_THRESHOLD  — 发起提案最低票权，默认 0
//   QUORUM_NUMERATOR    — 法定人数占总供给百分比分子（/100），默认 4
//   TIMELOCK_MIN_DELAY  — queue 后到可 execute 的秒数，默认 2 days
//
// forge script script/dao/DeployDAO.s.sol:DeployDAO \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {DAOToken} from "../../src/dao/DAOToken.sol";
import {DAOGov} from "../../src/dao/DAOGov.sol";
import {DAOBank} from "../../src/dao/DAOBank.sol";

contract DeployDAO is BaseScript {
    DAOToken public token;
    TimelockController public timelock;
    DAOGov public gov;
    DAOBank public bank;

    function run() public broadcaster {
        // Token 名称 / 符号（ERC20 name/symbol，同时用于 EIP-712 domain）
        string memory name_ = vm.envOr("NAME", string("DAO Token"));
        string memory symbol_ = vm.envOr("SYMBOL", string("DAO"));
        // 部署时铸给 deployer 的治理代币总量（18 decimals）
        uint256 initialSupply = vm.envOr("INITIAL_SUPPLY", uint256(1_000_000e18));
        // 提案创建后，再过多少个区块才开始投票（Pending → Active）
        uint48 votingDelay_ = uint48(vm.envOr("VOTING_DELAY", uint256(1)));
        // 投票窗口持续多少个区块（Active 期间可 castVote）
        uint32 votingPeriod_ = uint32(vm.envOr("VOTING_PERIOD", uint256(14)));
        // 发起提案所需的最低已委托票权；0 = 任意持有委托票权的人都能 propose
        uint256 proposalThreshold_ = vm.envOr("PROPOSAL_THRESHOLD", uint256(0));
        // 法定人数 = 提案快照时总供给 × 分子 / 100；默认 4 即需 ≥4% 赞成/弃权票才达标
        uint256 quorumNumerator_ = vm.envOr("QUORUM_NUMERATOR", uint256(4));
        // queue 之后再过多久（秒）才能 execute；默认 2 days
        uint256 timelockMinDelay = vm.envOr("TIMELOCK_MIN_DELAY", uint256(2 days));

        token = new DAOToken(name_, symbol_, deployer, initialSupply);

        // Timelock 角色名单（构造时写入）：
        // - proposers：谁能 queue/schedule。此时 Governor 尚未部署，先空着，后面 grantRole 给 gov
        // - executors：谁能在 minDelay 到期后 execute；address(0) = 任何人都可以触发执行
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // 开放执行：任何人可在 ETA 到达后触发 execute
        timelock = new TimelockController(timelockMinDelay, proposers, executors, deployer);

        gov = new DAOGov(token, timelock, votingDelay_, votingPeriod_, proposalThreshold_, quorumNumerator_);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(gov));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(gov));
        // 放弃 admin：之后改角色也必须走治理 + Timelock
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        bank = new DAOBank(address(timelock));

        // 教学演示：deployer 自委托，部署后立刻有票权
        token.delegate(deployer);

        saveContract("DAOToken", address(token));
        saveContract("TimelockController", address(timelock));
        saveContract("DAOGov", address(gov));
        saveContract("DAOBank", address(bank));

        console.log("DAOToken:            ", address(token));
        console.log("TimelockController:  ", address(timelock));
        console.log("DAOGov:              ", address(gov));
        console.log("DAOBank:             ", address(bank));
        console.log("bank.owner (lock):   ", bank.owner());
        console.log("timelock.minDelay:   ", timelock.getMinDelay());
        console.log("votingDelay:         ", votingDelay_);
        console.log("votingPeriod:        ", votingPeriod_);
        console.log("proposalThreshold:   ", proposalThreshold_);
        console.log("quorumNumerator:     ", quorumNumerator_);
        console.log("deployer votes:      ", token.getVotes(deployer));
    }
}
