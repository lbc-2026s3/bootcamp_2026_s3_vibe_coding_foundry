// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SealedBidAuction} from "../../src/auction/SealedBidAuction.sol";

/// @notice 首价密封拍卖：提交期只收哈希，披露期才付款，结束后按最高价结算。
///         forge test --match-path test/auction/SealedBidAuction.t.sol -vv
contract SealedBidAuctionTest is Test {
    SealedBidAuction internal auction;

    uint256 internal constant COMMIT_WINDOW = 1 hours;
    uint256 internal constant REVEAL_WINDOW = 1 hours;
    uint256 internal constant BOND = 0.05 ether;

    bytes32 internal constant ALICE_SECRET = keccak256("alice-secret");
    bytes32 internal constant BOB_SECRET = keccak256("bob-secret");
    bytes32 internal constant CAROL_SECRET = keccak256("carol-secret");

    address internal seller;
    address internal alice;
    address internal bob;
    address internal carol;

    function setUp() public {
        seller = makeAddr("seller");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        vm.prank(seller);
        auction = new SealedBidAuction(COMMIT_WINDOW, REVEAL_WINDOW, BOND);
    }

    function test_commit_stores_hash_not_the_bid() public {
        bytes32 commitment = auction.hashBid(alice, 5 ether, ALICE_SECRET);

        vm.expectEmit(true, false, false, true, address(auction));
        emit SealedBidAuction.Committed(alice, commitment);

        _commit(alice, 5 ether, ALICE_SECRET);

        assertEq(auction.commitments(alice), commitment);
        assertEq(auction.bids(alice), 0);
        assertEq(auction.highestBid(), 0);
        assertEq(auction.highestBidder(), address(0));
        assertEq(address(auction).balance, BOND);
        assertEq(uint256(auction.phase()), uint256(SealedBidAuction.Phase.Commit));
    }

    function test_highest_revealed_bid_is_paid_to_seller() public {
        _commit(alice, 5 ether, ALICE_SECRET);
        _commit(bob, 3 ether, BOB_SECRET);
        _commit(carol, 7 ether, CAROL_SECRET);

        _openReveal();
        _reveal(bob, 3 ether, BOB_SECRET);
        _reveal(alice, 5 ether, ALICE_SECRET);
        _reveal(carol, 7 ether, CAROL_SECRET);

        assertEq(auction.highestBidder(), carol);
        assertEq(auction.highestBid(), 7 ether);
        assertEq(auction.pendingReturns(bob), 3 ether + BOND);
        assertEq(auction.pendingReturns(alice), 5 ether + BOND);
        assertEq(auction.pendingReturns(carol), 0);

        vm.expectEmit(true, false, false, true, address(auction));
        emit SealedBidAuction.AuctionFinalized(carol, 7 ether);

        _endAuction();
        auction.finalize();

        assertEq(auction.pendingReturns(seller), 7 ether);
        assertEq(auction.pendingReturns(carol), BOND);

        uint256 sellerBefore = seller.balance;
        vm.prank(seller);
        auction.withdraw();
        assertEq(seller.balance - sellerBefore, 7 ether);

        uint256 carolBefore = carol.balance;
        vm.prank(carol);
        auction.withdraw();
        assertEq(carol.balance - carolBefore, BOND);

        _withdraw(alice);
        _withdraw(bob);

        assertEq(alice.balance, 5 ether + BOND);
        assertEq(bob.balance, 3 ether + BOND);
        assertEq(address(auction).balance, 0);
    }

    function test_bidder_cannot_commit_after_seeing_a_reveal() public {
        _commit(alice, 5 ether, ALICE_SECRET);
        _commit(bob, 3 ether, BOB_SECRET);

        _openReveal();
        _reveal(alice, 5 ether, ALICE_SECRET);

        bytes32 lateBid = auction.hashBid(bob, 6 ether, BOB_SECRET);
        vm.deal(bob, bob.balance + 6 ether);
        vm.prank(bob);
        vm.expectRevert(SealedBidAuction.CommitPhaseOver.selector);
        auction.commit{value: BOND}(lateBid);

        _reveal(bob, 3 ether, BOB_SECRET);
        assertEq(auction.highestBidder(), alice);
        assertEq(auction.highestBid(), 5 ether);
    }

    function test_copied_commitment_cannot_be_revealed_by_someone_else() public {
        _commit(alice, 5 ether, ALICE_SECRET);
        bytes32 stolen = auction.commitments(alice);

        vm.deal(bob, BOND + 5 ether);
        vm.prank(bob);
        auction.commit{value: BOND}(stolen);

        _openReveal();

        vm.prank(bob);
        vm.expectRevert(SealedBidAuction.InvalidReveal.selector);
        auction.reveal{value: 5 ether}(5 ether, ALICE_SECRET);

        _reveal(alice, 5 ether, ALICE_SECRET);
        assertEq(auction.highestBidder(), alice);
        assertEq(auction.bids(bob), 0);
    }

    function test_commitment_can_be_replaced_before_deadline() public {
        _commit(alice, 5 ether, ALICE_SECRET);

        bytes32 updated = auction.hashBid(alice, 8 ether, ALICE_SECRET);
        vm.prank(alice);
        auction.commit(updated);

        assertEq(auction.commitCount(), 1);
        assertEq(address(auction).balance, BOND);

        _openReveal();

        vm.deal(alice, alice.balance + 5 ether);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.InvalidReveal.selector);
        auction.reveal{value: 5 ether}(5 ether, ALICE_SECRET);

        _reveal(alice, 8 ether, ALICE_SECRET);
        assertEq(auction.highestBid(), 8 ether);
    }

    function test_unrevealed_bond_is_forfeited_to_seller() public {
        _commit(alice, 5 ether, ALICE_SECRET);
        _commit(carol, 4 ether, CAROL_SECRET);

        _openReveal();
        _reveal(alice, 5 ether, ALICE_SECRET);

        _endAuction();
        auction.finalize();

        assertEq(auction.pendingReturns(seller), 5 ether + BOND);
        assertEq(auction.pendingReturns(carol), 0);
        assertEq(auction.pendingReturns(alice), BOND);

        _withdraw(seller);
        _withdraw(alice);
        assertEq(address(auction).balance, 0);
    }

    function test_equal_bids_keep_the_earlier_reveal() public {
        _commit(alice, 5 ether, ALICE_SECRET);
        _commit(bob, 5 ether, BOB_SECRET);

        _openReveal();
        _reveal(alice, 5 ether, ALICE_SECRET);
        _reveal(bob, 5 ether, BOB_SECRET);

        assertEq(auction.highestBidder(), alice);
        assertEq(auction.pendingReturns(bob), 5 ether + BOND);
    }

    function test_zero_bond_still_settles_the_winning_bid() public {
        vm.prank(seller);
        SealedBidAuction openBond = new SealedBidAuction(COMMIT_WINDOW, REVEAL_WINDOW, 0);

        bytes32 aliceCommitment = openBond.hashBid(alice, 5 ether, ALICE_SECRET);
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        openBond.commit(aliceCommitment);

        bytes32 bobCommitment = openBond.hashBid(bob, 4 ether, BOB_SECRET);
        vm.deal(bob, 4 ether);
        vm.prank(bob);
        openBond.commit(bobCommitment);

        vm.warp(openBond.commitDeadline());
        vm.prank(alice);
        openBond.reveal{value: 5 ether}(5 ether, ALICE_SECRET);
        vm.prank(bob);
        openBond.reveal{value: 4 ether}(4 ether, BOB_SECRET);

        vm.warp(openBond.revealDeadline());
        openBond.finalize();

        assertEq(openBond.pendingReturns(seller), 5 ether);
        assertEq(openBond.pendingReturns(alice), 0);
        assertEq(openBond.pendingReturns(bob), 4 ether);

        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.NothingToWithdraw.selector);
        openBond.withdraw();
    }

    function test_revert_seller_cannot_commit() public {
        bytes32 sellerCommitment = auction.hashBid(seller, 1 ether, ALICE_SECRET);
        vm.deal(seller, BOND);
        vm.prank(seller);
        vm.expectRevert(SealedBidAuction.SellerCannotBid.selector);
        auction.commit{value: BOND}(sellerCommitment);
    }

    function test_revert_empty_commitment() public {
        vm.deal(alice, BOND);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.EmptyCommitment.selector);
        auction.commit{value: BOND}(bytes32(0));
    }

    function test_revert_wrong_bond() public {
        bytes32 commitment = auction.hashBid(alice, 1 ether, ALICE_SECRET);
        vm.deal(alice, BOND - 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SealedBidAuction.IncorrectBond.selector, BOND, BOND - 1));
        auction.commit{value: BOND - 1}(commitment);
    }

    function test_revert_replace_commitment_sends_bond_again() public {
        _commit(alice, 5 ether, ALICE_SECRET);

        bytes32 replacement = auction.hashBid(alice, 6 ether, ALICE_SECRET);
        vm.deal(alice, BOND);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SealedBidAuction.IncorrectBond.selector, 0, BOND));
        auction.commit{value: BOND}(replacement);
    }

    function test_revert_commit_once_reveal_has_started() public {
        _openReveal();

        bytes32 commitment = auction.hashBid(alice, 1 ether, ALICE_SECRET);
        vm.deal(alice, BOND);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.CommitPhaseOver.selector);
        auction.commit{value: BOND}(commitment);
    }

    function test_revert_reveal_during_commit_phase() public {
        _commit(alice, 5 ether, ALICE_SECRET);

        vm.deal(alice, 5 ether);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.NotRevealPhase.selector);
        auction.reveal{value: 5 ether}(5 ether, ALICE_SECRET);
    }

    function test_revert_reveal_after_deadline() public {
        _commit(alice, 5 ether, ALICE_SECRET);
        _endAuction();

        vm.deal(alice, 5 ether);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.NotRevealPhase.selector);
        auction.reveal{value: 5 ether}(5 ether, ALICE_SECRET);
    }

    function test_revert_reveal_without_commitment() public {
        _openReveal();

        vm.deal(alice, 5 ether);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.NoCommitment.selector);
        auction.reveal{value: 5 ether}(5 ether, ALICE_SECRET);
    }

    function test_revert_wrong_secret() public {
        _commit(alice, 5 ether, ALICE_SECRET);
        _openReveal();

        vm.deal(alice, 5 ether);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.InvalidReveal.selector);
        auction.reveal{value: 5 ether}(5 ether, BOB_SECRET);

        assertEq(auction.bids(alice), 0);
        assertEq(address(auction).balance, BOND);
    }

    function test_revert_payment_does_not_match_committed_amount() public {
        _commit(alice, 5 ether, ALICE_SECRET);
        _openReveal();

        vm.deal(alice, 4 ether);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SealedBidAuction.IncorrectPayment.selector, 5 ether, 4 ether));
        auction.reveal{value: 4 ether}(5 ether, ALICE_SECRET);
    }

    function test_revert_zero_bid() public {
        bytes32 zeroCommitment = auction.hashBid(alice, 0, ALICE_SECRET);
        vm.deal(alice, BOND);
        vm.prank(alice);
        auction.commit{value: BOND}(zeroCommitment);

        _openReveal();

        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.ZeroBid.selector);
        auction.reveal(0, ALICE_SECRET);
    }

    function test_revert_reveal_twice() public {
        _commit(alice, 5 ether, ALICE_SECRET);
        _openReveal();
        _reveal(alice, 5 ether, ALICE_SECRET);

        vm.deal(alice, 5 ether);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.AlreadyRevealed.selector);
        auction.reveal{value: 5 ether}(5 ether, ALICE_SECRET);
    }

    function test_revert_withdraw_before_end() public {
        _commit(alice, 5 ether, ALICE_SECRET);
        _commit(bob, 3 ether, BOB_SECRET);
        _openReveal();
        _reveal(alice, 5 ether, ALICE_SECRET);
        _reveal(bob, 3 ether, BOB_SECRET);

        vm.prank(bob);
        vm.expectRevert(SealedBidAuction.AuctionNotEnded.selector);
        auction.withdraw();
    }

    function test_revert_finalize_twice() public {
        _endAuction();
        auction.finalize();

        vm.expectRevert(SealedBidAuction.AlreadyFinalized.selector);
        auction.finalize();
    }

    function test_revert_zero_duration() public {
        vm.expectRevert(SealedBidAuction.ZeroDuration.selector);
        new SealedBidAuction(0, REVEAL_WINDOW, BOND);

        vm.expectRevert(SealedBidAuction.ZeroDuration.selector);
        new SealedBidAuction(COMMIT_WINDOW, 0, BOND);
    }

    function test_phase_changes_on_the_deadline() public {
        assertEq(uint256(auction.phase()), uint256(SealedBidAuction.Phase.Commit));

        vm.warp(auction.commitDeadline());
        assertEq(uint256(auction.phase()), uint256(SealedBidAuction.Phase.Reveal));

        vm.warp(auction.revealDeadline());
        assertEq(uint256(auction.phase()), uint256(SealedBidAuction.Phase.Ended));
    }

    function test_withdraw_reentrancy_is_rejected() public {
        ReentrantBidder attacker = new ReentrantBidder(auction);
        bytes32 secret = keccak256("attacker");

        bytes32 commitment = auction.hashBid(address(attacker), 2 ether, secret);
        vm.deal(address(attacker), BOND + 2 ether);
        attacker.commit(commitment);

        _commit(alice, 5 ether, ALICE_SECRET);

        _openReveal();
        attacker.reveal(2 ether, secret);
        _reveal(alice, 5 ether, ALICE_SECRET);

        _endAuction();
        auction.finalize();

        uint256 owed = auction.pendingReturns(address(attacker));
        assertEq(owed, 2 ether + BOND);

        attacker.withdraw();

        assertFalse(attacker.reentered());
        assertEq(auction.pendingReturns(address(attacker)), 0);
        assertEq(address(attacker).balance, owed);
    }

    function test_revert_withdraw_when_recipient_rejects_eth() public {
        RejectingBidder attacker = new RejectingBidder(auction);
        bytes32 secret = keccak256("reject");

        bytes32 commitment = auction.hashBid(address(attacker), 2 ether, secret);
        vm.deal(address(attacker), BOND + 2 ether);
        attacker.commit(commitment);
        _commit(alice, 5 ether, ALICE_SECRET);

        _openReveal();
        attacker.reveal(2 ether, secret);
        _reveal(alice, 5 ether, ALICE_SECRET);

        _endAuction();
        auction.finalize();

        vm.expectRevert(SealedBidAuction.TransferFailed.selector);
        attacker.withdraw();
        assertEq(auction.pendingReturns(address(attacker)), 2 ether + BOND);
    }

    function testFuzz_settlement_pays_seller_the_higher_bid(uint96 aliceBid, uint96 bobBid) public {
        aliceBid = uint96(bound(aliceBid, 1, 500 ether));
        bobBid = uint96(bound(bobBid, 1, 500 ether));
        vm.assume(aliceBid != bobBid);

        _commit(alice, aliceBid, ALICE_SECRET);
        _commit(bob, bobBid, BOB_SECRET);
        _openReveal();
        _reveal(alice, aliceBid, ALICE_SECRET);
        _reveal(bob, bobBid, BOB_SECRET);
        _endAuction();
        auction.finalize();

        uint256 winnerBid = aliceBid > bobBid ? aliceBid : bobBid;
        address winner = aliceBid > bobBid ? alice : bob;
        address loser = winner == alice ? bob : alice;
        uint256 loserBid = winner == alice ? bobBid : aliceBid;

        assertEq(auction.highestBidder(), winner);
        assertEq(auction.highestBid(), winnerBid);
        assertEq(auction.pendingReturns(seller), winnerBid);
        assertEq(auction.pendingReturns(winner), BOND);
        assertEq(auction.pendingReturns(loser), uint256(loserBid) + BOND);

        _withdraw(seller);
        _withdraw(winner);
        _withdraw(loser);
        assertEq(address(auction).balance, 0);
    }

    function _commit(address bidder, uint256 amount, bytes32 secret) private {
        bytes32 commitment = auction.hashBid(bidder, amount, secret);
        vm.deal(bidder, bidder.balance + BOND);
        vm.prank(bidder);
        auction.commit{value: BOND}(commitment);
    }

    function _reveal(address bidder, uint256 amount, bytes32 secret) private {
        vm.deal(bidder, bidder.balance + amount);
        vm.prank(bidder);
        auction.reveal{value: amount}(amount, secret);
    }

    function _withdraw(address account) private {
        vm.prank(account);
        auction.withdraw();
    }

    function _openReveal() private {
        vm.warp(auction.commitDeadline());
    }

    function _endAuction() private {
        vm.warp(auction.revealDeadline());
    }
}

contract ReentrantBidder {
    SealedBidAuction internal immutable auction;
    bool public reentered;

    constructor(SealedBidAuction auction_) {
        auction = auction_;
    }

    function commit(bytes32 commitment) external {
        auction.commit{value: auction.bidBond()}(commitment);
    }

    function reveal(uint256 amount, bytes32 secret) external payable {
        auction.reveal{value: amount}(amount, secret);
    }

    function withdraw() external {
        auction.withdraw();
    }

    receive() external payable {
        try auction.withdraw() {
            reentered = true;
        } catch (bytes memory reason) {
            bytes4 selector = bytes4(reason);
            if (selector != ReentrancyGuard.ReentrancyGuardReentrantCall.selector) {
                reentered = true;
            }
        }
    }
}

contract RejectingBidder {
    SealedBidAuction internal immutable auction;

    constructor(SealedBidAuction auction_) {
        auction = auction_;
    }

    function commit(bytes32 commitment) external {
        auction.commit{value: auction.bidBond()}(commitment);
    }

    function reveal(uint256 amount, bytes32 secret) external payable {
        auction.reveal{value: amount}(amount, secret);
    }

    function withdraw() external {
        auction.withdraw();
    }

    receive() external payable {
        revert("reject");
    }
}
