// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../../src/tokens/GovernanceToken.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken internal token;

    address internal deployer = makeAddr("deployer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public {
        vm.prank(deployer);
        token = new GovernanceToken();
    }

    function test_ConstructorMintsSupplyWithoutVotes() public view {
        assertEq(token.name(), "Governance Token");
        assertEq(token.symbol(), "GOV");
        assertEq(token.totalSupply(), token.INITIAL_SUPPLY());
        assertEq(token.balanceOf(deployer), token.INITIAL_SUPPLY());
        assertEq(token.getVotes(deployer), 0);
    }

    function test_SelfDelegateActivatesVotesAndTransferMovesThem() public {
        vm.prank(deployer);
        token.delegate(deployer);
        assertEq(token.getVotes(deployer), token.INITIAL_SUPPLY());

        vm.prank(alice);
        token.delegate(alice);

        vm.prank(deployer);
        token.transfer(alice, 40e18);

        assertEq(token.getVotes(deployer), token.INITIAL_SUPPLY() - 40e18);
        assertEq(token.getVotes(alice), 40e18);
        assertEq(token.delegates(alice), alice);
    }

    function test_RedelegateAfterTransferDoesNotLeaveStaleVotes() public {
        vm.prank(deployer);
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.delegate(bob);
        assertEq(token.getVotes(bob), 100e18);
        assertEq(token.balanceOf(bob), 0);

        vm.prank(alice);
        token.transfer(carol, 40e18);
        assertEq(token.getVotes(bob), 60e18);
        assertEq(token.getVotes(carol), 0);

        vm.prank(alice);
        token.delegate(carol);
        assertEq(token.getVotes(bob), 0);
        assertEq(token.getVotes(carol), 60e18);
        assertEq(token.balanceOf(carol), 40e18);
    }

    function testFuzz_TransferConservesDelegatedVotes(uint256 amount) public {
        amount = bound(amount, 0, token.INITIAL_SUPPLY());

        vm.prank(deployer);
        token.delegate(deployer);
        vm.prank(alice);
        token.delegate(alice);

        vm.prank(deployer);
        token.transfer(alice, amount);

        assertEq(token.getVotes(deployer) + token.getVotes(alice), token.INITIAL_SUPPLY());
        assertEq(token.balanceOf(deployer) + token.balanceOf(alice), token.INITIAL_SUPPLY());
    }

    function test_ProposeRevertsWhenDelegationIsStillInTheCurrentBlock() public {
        vm.prank(deployer);
        token.delegate(deployer);
        assertGe(token.getVotes(deployer), token.PROPOSAL_THRESHOLD());

        uint256 threshold = token.PROPOSAL_THRESHOLD();
        vm.expectRevert(
            abi.encodeWithSelector(GovernanceToken.InsufficientVotingPower.selector, deployer, 0, threshold)
        );
        vm.prank(deployer);
        token.propose("same block");
    }

    function test_ProposeRevertsForEmptyOrOversizedDescription() public {
        _activate(deployer);

        vm.startPrank(deployer);
        vm.expectRevert(GovernanceToken.EmptyDescription.selector);
        token.propose("");

        string memory huge = new string(token.MAX_DESCRIPTION_BYTES() + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                GovernanceToken.DescriptionTooLong.selector,
                token.MAX_DESCRIPTION_BYTES() + 1,
                token.MAX_DESCRIPTION_BYTES()
            )
        );
        token.propose(huge);
        vm.stopPrank();
    }

    function test_VoteUsesSnapshotAndIgnoresLaterTransfers() public {
        _activate(deployer);
        uint256 proposalId = _propose("ship it");
        uint256 snapshot = block.number + token.VOTING_DELAY();

        vm.roll(_startBlock(proposalId));
        vm.prank(deployer);
        token.transfer(alice, 250_000e18);

        vm.prank(alice);
        token.delegate(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.NoVotingPower.selector, alice));
        token.vote(proposalId, true);

        vm.prank(deployer);
        token.vote(proposalId, true);

        assertEq(_forVotes(proposalId), token.INITIAL_SUPPLY());
        assertEq(token.getPastVotes(deployer, snapshot), token.INITIAL_SUPPLY());
        assertEq(token.getVotes(deployer), token.INITIAL_SUPPLY() - 250_000e18);

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.AlreadyVoted.selector, proposalId, deployer));
        token.vote(proposalId, false);
    }

    function test_PassingProposalCanBeExecutedByAnyone() public {
        _activate(deployer);
        uint256 proposalId = _propose("pass");
        _rollToVoting(proposalId);

        vm.prank(deployer);
        token.vote(proposalId, true);

        vm.roll(_endBlock(proposalId) + 1);
        assertEq(uint256(token.state(proposalId)), uint256(GovernanceToken.ProposalState.Succeeded));

        vm.prank(carol);
        token.executeProposal(proposalId);

        assertEq(uint256(token.state(proposalId)), uint256(GovernanceToken.ProposalState.Executed));
        assertTrue(_executed(proposalId));
    }

    function test_ExecuteRevertsWhenQuorumOrMajorityFails() public {
        uint256 minority = token.PROPOSAL_THRESHOLD();
        uint256 majority = token.INITIAL_SUPPLY() - minority;
        vm.prank(deployer);
        token.transfer(alice, majority);
        _activate(deployer);
        _activate(alice);

        uint256 proposalId = _propose("too small");
        _rollToVoting(proposalId);

        vm.prank(deployer);
        token.vote(proposalId, true);
        vm.prank(alice);
        token.vote(proposalId, false);

        vm.roll(_endBlock(proposalId) + 1);
        assertEq(uint256(token.state(proposalId)), uint256(GovernanceToken.ProposalState.Defeated));

        vm.expectRevert(
            abi.encodeWithSelector(GovernanceToken.ProposalNotPassed.selector, proposalId, minority, majority)
        );
        token.executeProposal(proposalId);
    }

    function test_ExecuteRevertsWhenForVotesWinButMissQuorum() public {
        uint256 keep = token.PROPOSAL_THRESHOLD();
        uint256 give = token.INITIAL_SUPPLY() - keep;
        vm.prank(deployer);
        token.transfer(alice, give);
        _activate(deployer);

        uint256 proposalId = _propose("no quorum");
        _rollToVoting(proposalId);

        vm.prank(deployer);
        token.vote(proposalId, true);

        uint256 end = _endBlock(proposalId);
        vm.roll(end + 1);
        uint256 required = token.quorum(_snapshot(proposalId));
        assertLt(keep, required);

        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.QuorumNotReached.selector, proposalId, keep, required));
        token.executeProposal(proposalId);
    }

    function test_TieDoesNotPass() public {
        uint256 half = token.INITIAL_SUPPLY() / 2;
        vm.prank(deployer);
        token.transfer(alice, half);
        _activate(deployer);
        _activate(alice);

        uint256 proposalId = _propose("tie");
        _rollToVoting(proposalId);

        vm.prank(deployer);
        token.vote(proposalId, true);
        vm.prank(alice);
        token.vote(proposalId, false);

        vm.roll(_endBlock(proposalId) + 1);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.ProposalNotPassed.selector, proposalId, half, half));
        token.executeProposal(proposalId);
    }

    function test_ProposerCanCancelBeforeVotingEnds() public {
        _activate(deployer);
        uint256 proposalId = _propose("withdraw");

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.NotProposer.selector, alice, deployer));
        token.cancelProposal(proposalId);

        vm.prank(deployer);
        token.cancelProposal(proposalId);
        assertEq(uint256(token.state(proposalId)), uint256(GovernanceToken.ProposalState.Canceled));

        vm.roll(_startBlock(proposalId));
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.ProposalAlreadyCanceled.selector, proposalId));
        token.vote(proposalId, true);

        vm.roll(_endBlock(proposalId) + 1);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.ProposalAlreadyCanceled.selector, proposalId));
        token.executeProposal(proposalId);
    }

    function test_RevertWhenVotingOutsideWindowOrProposalMissing() public {
        _activate(deployer);
        uint256 proposalId = _propose("window");

        uint256 startBlock = _startBlock(proposalId);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.VotingNotStarted.selector, proposalId, startBlock));
        vm.prank(deployer);
        token.vote(proposalId, true);

        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.ProposalNotFound.selector, 0));
        token.vote(0, true);

        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.ProposalNotFound.selector, 99));
        token.state(99);

        uint256 endedAt = _endBlock(proposalId);
        vm.roll(endedAt + 1);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.VotingEnded.selector, proposalId, endedAt));
        vm.prank(deployer);
        token.vote(proposalId, true);

        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.CancelWindowClosed.selector, proposalId));
        vm.prank(deployer);
        token.cancelProposal(proposalId);

        uint256 endBlock = _endBlock(proposalId);
        vm.roll(endBlock);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.VotingNotEnded.selector, proposalId, endBlock));
        token.executeProposal(proposalId);
    }

    function _activate(address account) internal {
        vm.prank(account);
        token.delegate(account);
        vm.roll(block.number + 1);
    }

    function _propose(string memory description) internal returns (uint256 proposalId) {
        vm.prank(deployer);
        proposalId = token.propose(description);
    }

    function _rollToVoting(uint256 proposalId) internal {
        vm.roll(_startBlock(proposalId));
    }

    function _startBlock(uint256 proposalId) internal view returns (uint256 startBlock) {
        (,,,, startBlock,,,,,) = token.proposals(proposalId);
    }

    function _endBlock(uint256 proposalId) internal view returns (uint256 endBlock) {
        (,,,,, endBlock,,,,) = token.proposals(proposalId);
    }

    function _snapshot(uint256 proposalId) internal view returns (uint256 snapshotBlock) {
        (,,, snapshotBlock,,,,,,) = token.proposals(proposalId);
    }

    function _forVotes(uint256 proposalId) internal view returns (uint256 forVotes) {
        (,,,,,, forVotes,,,) = token.proposals(proposalId);
    }

    function _executed(uint256 proposalId) internal view returns (bool executed) {
        (,,,,,,,, executed,) = token.proposals(proposalId);
    }
}
