// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {DAOVoting} from "../../src/eip-712/DAOVoting.sol";

/// @notice 离线签 `Vote`，由中继 `castVotesBySig` 上链计票。
///         forge test --match-path test/eip-712/DAOVoting.t.sol -vv
contract DAOVotingTest is Test {
    DAOVoting internal voting;

    uint256 internal constant ALICE_PK = 0xA11CE;
    uint256 internal constant BOB_PK = 0xB0B;

    address internal alice;
    address internal bob;
    address internal relayer = makeAddr("relayer");

    uint256 internal constant PROPOSAL = 1;
    uint256 internal constant ALICE_WEIGHT = 100;
    uint256 internal constant BOB_WEIGHT = 40;

    function setUp() public {
        voting = new DAOVoting();
        alice = vm.addr(ALICE_PK);
        bob = vm.addr(BOB_PK);
    }

    function test_domain_matches_constructor() public view {
        (bytes1 fields, string memory name, string memory version, uint256 chainId, address verifyingContract,,) =
            voting.eip712Domain();

        assertEq(fields, hex"0f");
        assertEq(name, "DAOVoting");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(voting));
    }

    function test_relayer_casts_for_and_against() public {
        DAOVoting.Vote memory aliceVote = _vote(PROPOSAL, true, alice, ALICE_WEIGHT, 0);
        DAOVoting.Vote memory bobVote = _vote(PROPOSAL, false, bob, BOB_WEIGHT, 0);

        vm.expectEmit(true, true, false, true, address(voting));
        emit DAOVoting.VoteCast(PROPOSAL, alice, true, ALICE_WEIGHT, 0, aliceVote.deadline);

        vm.prank(relayer);
        voting.castVotesBySig(_batch(aliceVote, bobVote), _sigs(ALICE_PK, aliceVote, BOB_PK, bobVote));

        assertEq(voting.forVotes(PROPOSAL), ALICE_WEIGHT);
        assertEq(voting.againstVotes(PROPOSAL), BOB_WEIGHT);
        assertTrue(voting.hasVoted(PROPOSAL, alice));
        assertTrue(voting.hasVoted(PROPOSAL, bob));
        assertEq(voting.nonces(alice), 1);
        assertEq(voting.nonces(bob), 1);
        assertEq(voting.forVotes(2), 0);
    }

    function test_same_voter_uses_sequential_nonces_across_proposals() public {
        DAOVoting.Vote memory first = _vote(1, true, alice, 10, 0);
        DAOVoting.Vote memory second = _vote(2, false, alice, 25, 1);

        voting.castVotesBySig(_batch(first, second), _sigs(ALICE_PK, first, ALICE_PK, second));

        assertEq(voting.forVotes(1), 10);
        assertEq(voting.againstVotes(2), 25);
        assertEq(voting.nonces(alice), 2);
        assertTrue(voting.hasVoted(1, alice));
        assertTrue(voting.hasVoted(2, alice));
    }

    function test_revert_replay_same_signature() public {
        DAOVoting.Vote memory vote = _vote(PROPOSAL, true, alice, ALICE_WEIGHT, 0);
        bytes[] memory signatures = _oneSig(ALICE_PK, vote);

        voting.castVotesBySig(_one(vote), signatures);

        vm.expectRevert(abi.encodeWithSelector(DAOVoting.InvalidNonce.selector, alice, 1, 0));
        voting.castVotesBySig(_one(vote), signatures);
    }

    function test_revert_already_voted_same_proposal() public {
        DAOVoting.Vote memory first = _vote(PROPOSAL, true, alice, 10, 0);
        voting.castVotesBySig(_one(first), _oneSig(ALICE_PK, first));

        DAOVoting.Vote memory again = _vote(PROPOSAL, false, alice, 10, 1);
        bytes[] memory againSigs = _oneSig(ALICE_PK, again);
        vm.expectRevert(abi.encodeWithSelector(DAOVoting.AlreadyVoted.selector, PROPOSAL, alice));
        voting.castVotesBySig(_one(again), againSigs);

        assertEq(voting.forVotes(PROPOSAL), 10);
        assertEq(voting.againstVotes(PROPOSAL), 0);
        assertEq(voting.nonces(alice), 1);
    }

    function test_revert_skipped_nonce() public {
        DAOVoting.Vote memory vote = _vote(PROPOSAL, true, alice, ALICE_WEIGHT, 1);
        bytes[] memory signatures = _oneSig(ALICE_PK, vote);
        vm.expectRevert(abi.encodeWithSelector(DAOVoting.InvalidNonce.selector, alice, 0, 1));
        voting.castVotesBySig(_one(vote), signatures);
    }

    function test_revert_signer_is_not_voter() public {
        DAOVoting.Vote memory vote = _vote(PROPOSAL, true, alice, ALICE_WEIGHT, 0);
        bytes[] memory signatures = _oneSig(BOB_PK, vote);
        vm.expectRevert(abi.encodeWithSelector(DAOVoting.InvalidSigner.selector, bob, alice));
        voting.castVotesBySig(_one(vote), signatures);
    }

    function test_revert_tampered_weight() public {
        DAOVoting.Vote memory signedVote = _vote(PROPOSAL, true, alice, ALICE_WEIGHT, 0);
        bytes memory signature = _sign(ALICE_PK, signedVote);

        DAOVoting.Vote memory tampered = signedVote;
        tampered.weight = ALICE_WEIGHT + 1;

        vm.expectRevert();
        voting.castVotesBySig(_one(tampered), _wrap(signature));
        assertFalse(voting.hasVoted(PROPOSAL, alice));
        assertEq(voting.forVotes(PROPOSAL), 0);
    }

    function test_revert_wrong_chain_id_in_digest() public {
        DAOVoting.Vote memory vote = _vote(PROPOSAL, true, alice, ALICE_WEIGHT, 0);
        bytes32 digest = _digest(vote, block.chainid + 1, address(voting));
        bytes memory signature = _signDigest(ALICE_PK, digest);

        vm.expectRevert();
        voting.castVotesBySig(_one(vote), _wrap(signature));
        assertFalse(voting.hasVoted(PROPOSAL, alice));
    }

    function test_revert_length_mismatch_and_empty_batch() public {
        DAOVoting.Vote memory vote = _vote(PROPOSAL, true, alice, ALICE_WEIGHT, 0);

        vm.expectRevert(abi.encodeWithSelector(DAOVoting.LengthMismatch.selector, 1, 0));
        voting.castVotesBySig(_one(vote), new bytes[](0));

        DAOVoting.Vote[] memory none = new DAOVoting.Vote[](0);
        vm.expectRevert(DAOVoting.EmptyBatch.selector);
        voting.castVotesBySig(none, new bytes[](0));
    }

    function test_accepts_vote_at_exact_deadline() public {
        uint256 deadline = block.timestamp + 1 hours;
        DAOVoting.Vote memory vote = _voteWithDeadline(PROPOSAL, true, alice, ALICE_WEIGHT, 0, deadline);
        bytes[] memory signatures = _oneSig(ALICE_PK, vote);

        vm.warp(deadline);
        voting.castVotesBySig(_one(vote), signatures);

        assertTrue(voting.hasVoted(PROPOSAL, alice));
        assertEq(voting.nonces(alice), 1);
    }

    function test_revert_expired_signature_does_not_consume_nonce() public {
        uint256 deadline = block.timestamp + 1 hours;
        DAOVoting.Vote memory vote = _voteWithDeadline(PROPOSAL, true, alice, ALICE_WEIGHT, 0, deadline);
        bytes[] memory signatures = _oneSig(ALICE_PK, vote);

        uint256 expiredAt = deadline + 1;
        vm.warp(expiredAt);
        vm.expectRevert(abi.encodeWithSelector(DAOVoting.SignatureExpired.selector, deadline, expiredAt));
        voting.castVotesBySig(_one(vote), signatures);

        assertEq(voting.nonces(alice), 0);
        assertFalse(voting.hasVoted(PROPOSAL, alice));
    }

    function test_revert_tampered_deadline() public {
        DAOVoting.Vote memory signedVote = _vote(PROPOSAL, true, alice, ALICE_WEIGHT, 0);
        bytes memory signature = _sign(ALICE_PK, signedVote);

        DAOVoting.Vote memory tampered = signedVote;
        tampered.deadline = signedVote.deadline + 1 days;

        vm.expectRevert();
        voting.castVotesBySig(_one(tampered), _wrap(signature));
        assertEq(voting.nonces(alice), 0);
    }

    function test_revert_zero_weight() public {
        DAOVoting.Vote memory vote = _vote(PROPOSAL, true, alice, 0, 0);
        bytes[] memory signatures = _oneSig(ALICE_PK, vote);
        vm.expectRevert(abi.encodeWithSelector(DAOVoting.ZeroWeight.selector, alice));
        voting.castVotesBySig(_one(vote), signatures);
    }

    function test_revert_malformed_signature() public {
        DAOVoting.Vote memory vote = _vote(PROPOSAL, true, alice, ALICE_WEIGHT, 0);
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 1));
        voting.castVotesBySig(_one(vote), _wrap(hex"00"));
    }

    function testFuzz_signed_weight_is_what_gets_counted(uint256 weight, bool support, uint256 proposalId) public {
        weight = bound(weight, 1, type(uint128).max);

        DAOVoting.Vote memory vote = _vote(proposalId, support, alice, weight, 0);
        voting.castVotesBySig(_one(vote), _oneSig(ALICE_PK, vote));

        if (support) {
            assertEq(voting.forVotes(proposalId), weight);
            assertEq(voting.againstVotes(proposalId), 0);
        } else {
            assertEq(voting.forVotes(proposalId), 0);
            assertEq(voting.againstVotes(proposalId), weight);
        }
        assertEq(voting.nonces(alice), 1);
    }

    function _vote(uint256 proposalId, bool support, address voter, uint256 weight, uint256 nonce)
        private
        view
        returns (DAOVoting.Vote memory)
    {
        return _voteWithDeadline(proposalId, support, voter, weight, nonce, block.timestamp + 1 days);
    }

    function _voteWithDeadline(
        uint256 proposalId,
        bool support,
        address voter,
        uint256 weight,
        uint256 nonce,
        uint256 deadline
    ) private pure returns (DAOVoting.Vote memory) {
        return DAOVoting.Vote({
            proposalId: proposalId,
            support: support,
            voter: voter,
            weight: weight,
            nonce: nonce,
            deadline: deadline
        });
    }

    function _sign(uint256 pk, DAOVoting.Vote memory vote) private view returns (bytes memory) {
        return _signDigest(pk, _digest(vote, block.chainid, address(voting)));
    }

    function _signDigest(uint256 pk, bytes32 digest) private pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _digest(DAOVoting.Vote memory vote, uint256 chainId, address verifyingContract)
        private
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                voting.VOTE_TYPEHASH(),
                vote.proposalId,
                vote.support,
                vote.voter,
                vote.weight,
                vote.nonce,
                vote.deadline
            )
        );
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("DAOVoting")),
                keccak256(bytes("1")),
                chainId,
                verifyingContract
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function _one(DAOVoting.Vote memory vote) private pure returns (DAOVoting.Vote[] memory votes) {
        votes = new DAOVoting.Vote[](1);
        votes[0] = vote;
    }

    function _oneSig(uint256 pk, DAOVoting.Vote memory vote) private view returns (bytes[] memory signatures) {
        signatures = new bytes[](1);
        signatures[0] = _sign(pk, vote);
    }

    function _batch(DAOVoting.Vote memory a, DAOVoting.Vote memory b)
        private
        pure
        returns (DAOVoting.Vote[] memory votes)
    {
        votes = new DAOVoting.Vote[](2);
        votes[0] = a;
        votes[1] = b;
    }

    function _sigs(uint256 pkA, DAOVoting.Vote memory a, uint256 pkB, DAOVoting.Vote memory b)
        private
        view
        returns (bytes[] memory signatures)
    {
        signatures = new bytes[](2);
        signatures[0] = _sign(pkA, a);
        signatures[1] = _sign(pkB, b);
    }

    function _wrap(bytes memory signature) private pure returns (bytes[] memory signatures) {
        signatures = new bytes[](1);
        signatures[0] = signature;
    }
}
