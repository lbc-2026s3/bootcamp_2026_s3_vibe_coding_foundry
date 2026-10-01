// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "openzeppelin-contracts/contracts/governance/IGovernor.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {DAOBank} from "../../src/dao/DAOBank.sol";
import {DAOToken} from "../../src/dao/DAOToken.sol";
import {DAOGov} from "../../src/dao/DAOGov.sol";

/// @notice DAO 治理金库端到端测试：propose → vote → queue → 等 minDelay → execute withdraw
contract DAOGovTest is Test {
    DAOToken internal token;
    TimelockController internal timelock;
    DAOGov internal gov;
    DAOBank internal bank;

    address internal deployer = makeAddr("deployer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal recipient = makeAddr("recipient");

    uint256 internal constant SUPPLY = 1_000_000e18; // 初始治理代币总量（铸给 deployer 后分给投票人）
    uint48 internal constant VOTING_DELAY = 1; // 提案创建后，再过多少个区块才开始投票（Pending → Active）
    uint32 internal constant VOTING_PERIOD = 14; // 投票窗口持续多少个区块（Active 期间可 castVote）
    uint256 internal constant PROPOSAL_THRESHOLD = 0; // 发起提案所需最低已委托票权；0 = 有票即可 propose
    uint256 internal constant QUORUM_NUMERATOR = 4; // 法定人数 = 快照总供给 × 4 / 100（即 4%）
    uint256 internal constant TIMELOCK_MIN_DELAY = 2 days; // 投票通过并 queue 后，再过多久才能 execute

    function _encodeStateBitmap(IGovernor.ProposalState proposalState) private pure returns (bytes32) {
        return bytes32(1 << uint8(proposalState));
    }

    function setUp() public {
        vm.startPrank(deployer);

        token = new DAOToken("DAO Token", "DAO", deployer, SUPPLY);

        // Timelock 角色名单（构造时写入）：
        // - proposers：谁能 queue/schedule。此时 Governor 尚未部署，先空着，后面 grantRole 给 gov
        // - executors：谁能在 minDelay 到期后 execute；address(0) = 任何人都可以触发执行
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(TIMELOCK_MIN_DELAY, proposers, executors, deployer);

        gov = new DAOGov(
            token, timelock, VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD, QUORUM_NUMERATOR
        );

        // 只有 Governor 能向 Timelock 排队 / 取消；随后放弃 admin，角色变更也须走提案
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(gov));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(gov));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // Bank owner = Timelock（真正花钱的是延迟执行器，不是 Governor 本身）
        bank = new DAOBank(address(timelock));

        token.transfer(alice, 600_000e18);
        token.transfer(bob, 400_000e18);
        vm.stopPrank();

        vm.prank(alice);
        token.delegate(alice);
        vm.prank(bob);
        token.delegate(bob);

        vm.roll(block.number + 1);
    }

    // ─── DAOBank ───

    function test_DepositIncreasesBalanceAndAccounting() public {
        vm.deal(alice, 10 ether);

        vm.prank(alice);
        bank.deposit{value: 3 ether}();

        assertEq(address(bank).balance, 3 ether);
        assertEq(bank.deposits(alice), 3 ether);
        assertEq(alice.balance, 7 ether);
    }

    function test_ReceiveAlsoDeposits() public {
        vm.deal(bob, 2 ether);

        vm.prank(bob);
        (bool ok,) = address(bank).call{value: 2 ether}("");
        assertTrue(ok);

        assertEq(bank.deposits(bob), 2 ether);
        assertEq(address(bank).balance, 2 ether);
        assertEq(bob.balance, 0 ether);
    }

    function test_RevertWhen_NonOwnerWithdraws() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        bank.withdraw(alice, 1 ether);
    }

    function test_BankOwnerIsTimelock() public view {
        assertEq(bank.owner(), address(timelock));
        assertEq(gov.timelock(), address(timelock));
    }

    // ─── 治理：propose → vote → queue → warp → execute withdraw ───

    function test_ProposeVoteQueueExecuteWithdraw() public {
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        bank.deposit{value: 5 ether}();
        assertEq(address(bank).balance, 5 ether);

        uint256 withdrawAmount = 2 ether;
        address[] memory targets = new address[](1);
        targets[0] = address(bank);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(DAOBank.withdraw, (recipient, withdrawAmount));
        string memory description = "Withdraw 2 ETH to recipient";
        bytes32 descriptionHash = keccak256(bytes(description));

        vm.prank(alice);
        uint256 proposalId = gov.propose(targets, values, calldatas, description);
        assertEq(uint256(gov.state(proposalId)), uint256(IGovernor.ProposalState.Pending));

        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint256(gov.state(proposalId)), uint256(IGovernor.ProposalState.Active));

        // 投赞成票：support = 0 Against / 1 For / 2 Abstain（GovernorCountingSimple）
        // 一次投票会把该账户在提案 snapshot 时的全部 getPastVotes 记到所选选项，不能拆分
        // （不能一半赞成一半反对；要拆分需用 GovernorCountingFractional）
        vm.prank(alice);
        gov.castVote(proposalId, 1);
        vm.prank(bob);
        gov.castVote(proposalId, 1);

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = gov.proposalVotes(proposalId);
        uint256 snapshot = gov.proposalSnapshot(proposalId);
        uint256 expectedFor =
            token.getPastVotes(alice, snapshot) + token.getPastVotes(bob, snapshot);
        assertEq(againstVotes, 0);
        assertEq(forVotes, expectedFor);
        assertEq(abstainVotes, 0);

        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(gov.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // 排队进 Timelock；未到 minDelay 前不能执行
        gov.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint256(gov.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        // 延迟未满：execute 会失败（Timelock 尚未 Ready）
        vm.expectRevert();
        gov.execute(targets, values, calldatas, descriptionHash);

        // 等到 minDelay 之后再执行
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY);
        uint256 recipientBefore = recipient.balance;
        gov.execute(targets, values, calldatas, descriptionHash);

        assertEq(uint256(gov.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
        assertEq(address(bank).balance, 3 ether);
        assertEq(recipient.balance, recipientBefore + withdrawAmount);
    }

    function test_RevertWhen_ProposalDefeatedCannotQueue() public {
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        bank.deposit{value: 5 ether}();

        address[] memory targets = new address[](1);
        targets[0] = address(bank);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(DAOBank.withdraw, (recipient, 1 ether));
        string memory description = "Should fail";
        bytes32 descriptionHash = keccak256(bytes(description));

        vm.prank(alice);
        uint256 proposalId = gov.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        gov.castVote(proposalId, 0);
        vm.prank(bob);
        gov.castVote(proposalId, 0);

        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(gov.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));

        // 有 Timelock 时须先 queue（仅 Succeeded）；Defeated 不能排队
        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorUnexpectedProposalState.selector,
                proposalId,
                IGovernor.ProposalState.Defeated,
                _encodeStateBitmap(IGovernor.ProposalState.Succeeded)
            )
        );
        gov.queue(targets, values, calldatas, descriptionHash);
    }

    /// @notice 无人投票 → 达不到法定人数 → Defeated
    /// @dev quorum = 快照总供给 × 4%；CountingSimple 用 For + Abstain 计 quorum。
    ///      全程 0 票 → forVotes+abstainVotes = 0 < quorum，投票期结束后状态为 Defeated（不是 Succeeded）。
    function test_QuorumNotReachedStaysDefeated() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        address[] memory targets = new address[](1);
        targets[0] = address(bank);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(DAOBank.withdraw, (recipient, 1 ether));
        string memory description = "No votes";

        vm.prank(alice);
        uint256 proposalId = gov.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);
        // Active 期间故意不 castVote
        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(gov.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }
}
