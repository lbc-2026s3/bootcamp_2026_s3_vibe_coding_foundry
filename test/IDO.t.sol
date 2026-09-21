// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IDO} from "../src/IDO.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";

contract RefundAttacker {
    IDO public ido;
    bool public attacking;

    constructor(IDO ido_) {
        ido = ido_;
    }

    receive() external payable {
        if (attacking) {
            attacking = false;
            ido.refund();
        }
    }

    function buy() external payable {
        ido.presale{value: msg.value}();
    }

    function attack() external {
        attacking = true;
        ido.refund();
    }

    function refundHonest() external {
        attacking = false;
        ido.refund();
    }
}

contract IDOTest is Test {
    IDO public ido;
    MyTokenV1 public token;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant DURATION = 7 days;

    function setUp() public {
        vm.startPrank(owner);
        token = new MyTokenV1();
        ido = new IDO(address(token), DURATION);
        token.transfer(address(ido), token.INITIAL_SUPPLY());
        vm.stopPrank();
    }

    function _presale(address user, uint256 amount) internal {
        vm.deal(user, amount);
        vm.prank(user);
        ido.presale{value: amount}();
    }

    function _endAndFinalize() internal {
        vm.warp(ido.deadline());
        ido.finalize();
    }

    function test_Constructor_SetsOwnerTokenAndDeadline() public view {
        assertEq(ido.owner(), owner);
        assertEq(address(ido.opsToken()), address(token));
        assertEq(ido.deadline(), block.timestamp + DURATION);
        assertEq(token.balanceOf(address(ido)), token.INITIAL_SUPPLY());
    }

    function test_RevertWhen_Constructor_ZeroToken() public {
        vm.expectRevert("Invalid token");
        new IDO(address(0), DURATION);
    }

    function test_Presale_RecordsContribution() public {
        vm.expectEmit(true, false, false, true);
        emit IDO.Presaled(alice, 1 ether);

        _presale(alice, 1 ether);

        assertEq(ido.contributions(alice), 1 ether);
        assertEq(ido.totalRaised(), 1 ether);
        assertEq(address(ido).balance, 1 ether);
    }

    function test_Receive_RecordsContribution() public {
        vm.deal(alice, 0.5 ether);
        vm.expectEmit(true, false, false, true);
        emit IDO.Presaled(alice, 0.5 ether);

        vm.prank(alice);
        (bool ok,) = address(ido).call{value: 0.5 ether}("");

        assertTrue(ok);
        assertEq(ido.contributions(alice), 0.5 ether);
        assertEq(ido.totalRaised(), 0.5 ether);
    }

    function test_Presale_AccumulatesAcrossCalls() public {
        _presale(alice, 1 ether);
        _presale(alice, 2 ether);

        assertEq(ido.contributions(alice), 3 ether);
        assertEq(ido.totalRaised(), 3 ether);
    }

    function test_RevertWhen_Presale_BelowMinContribution() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert("Below min contribution");
        ido.presale{value: 0.0009 ether}();
    }

    function test_RevertWhen_Presale_AfterDeadline() public {
        vm.warp(ido.deadline());
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert("IDO ended");
        ido.presale{value: 1 ether}();
    }

    function test_RevertWhen_Receive_AfterDeadline() public {
        vm.warp(ido.deadline());
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok, bytes memory data) = address(ido).call{value: 1 ether}("");
        assertFalse(ok);
        assertEq(data, abi.encodeWithSignature("Error(string)", "IDO ended"));
    }

    function test_RevertWhen_Presale_ExceedsHardCap() public {
        _presale(alice, ido.HARD_CAP());

        vm.deal(bob, 1 ether);
        vm.prank(bob);
        vm.expectRevert("Exceeds hard cap");
        ido.presale{value: 1 ether}();
    }

    function test_RevertWhen_Finalize_BeforeDeadline() public {
        vm.expectRevert("IDO not ended");
        ido.finalize();
    }

    function test_Finalize_SuccessWhenSoftCapReached() public {
        _presale(alice, ido.SOFT_CAP());

        vm.warp(ido.deadline());
        vm.expectEmit(false, false, false, true);
        emit IDO.Finalized(true);
        ido.finalize();

        assertTrue(ido.finalized());
        assertTrue(ido.success());
    }

    function test_Finalize_FailsWhenBelowSoftCap() public {
        _presale(alice, 50 ether);

        vm.warp(ido.deadline());
        vm.expectEmit(false, false, false, true);
        emit IDO.Finalized(false);
        ido.finalize();

        assertTrue(ido.finalized());
        assertFalse(ido.success());
    }

    function test_RevertWhen_Finalize_Twice() public {
        vm.warp(ido.deadline());
        ido.finalize();

        vm.expectRevert("Already finalized");
        ido.finalize();
    }

    function test_Claim_TransfersTokensProportionalToContribution() public {
        _presale(alice, ido.SOFT_CAP());
        _endAndFinalize();

        uint256 expectedTokens = (ido.SOFT_CAP() * 1e18) / ido.TOKEN_PRICE();
        assertEq(expectedTokens, ido.TOTAL_TOKENS());

        vm.expectEmit(true, false, false, true);
        emit IDO.Claimed(alice, expectedTokens);

        vm.prank(alice);
        ido.claim();

        assertEq(token.balanceOf(alice), expectedTokens);
        assertEq(ido.claimed(alice), expectedTokens);
        assertEq(ido.totalClaimed(), expectedTokens);
        assertEq(token.balanceOf(address(ido)), 0);
    }

    function test_Claim_TwoUsersSplitTokens() public {
        _presale(alice, 40 ether);
        _presale(bob, 60 ether);
        _endAndFinalize();

        vm.prank(alice);
        ido.claim();
        vm.prank(bob);
        ido.claim();

        assertEq(token.balanceOf(alice), (40 ether * 1e18) / ido.TOKEN_PRICE());
        assertEq(token.balanceOf(bob), (60 ether * 1e18) / ido.TOKEN_PRICE());
        assertEq(ido.totalClaimed(), ido.TOTAL_TOKENS());
    }

    function test_RevertWhen_Claim_NotFinalized() public {
        _presale(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert("Not finalized");
        ido.claim();
    }

    function test_RevertWhen_Claim_FailedIdo() public {
        _presale(alice, 50 ether);
        _endAndFinalize();

        vm.prank(alice);
        vm.expectRevert("IDO failed");
        ido.claim();
    }

    function test_RevertWhen_Claim_NoContribution() public {
        _presale(alice, ido.SOFT_CAP());
        _endAndFinalize();

        vm.prank(bob);
        vm.expectRevert("No contribution");
        ido.claim();
    }

    function test_RevertWhen_Claim_Twice() public {
        _presale(alice, ido.SOFT_CAP());
        _endAndFinalize();

        vm.prank(alice);
        ido.claim();

        vm.prank(alice);
        vm.expectRevert("Already claimed");
        ido.claim();
    }

    function test_Refund_ReturnsEthWhenFailed() public {
        _presale(alice, 50 ether);
        _endAndFinalize();

        uint256 aliceBefore = alice.balance;
        vm.expectEmit(true, false, false, true);
        emit IDO.Refunded(alice, 50 ether);

        vm.prank(alice);
        ido.refund();

        assertEq(alice.balance, aliceBefore + 50 ether);
        assertEq(ido.contributions(alice), 0);
        assertEq(address(ido).balance, 0);
    }

    function test_RevertWhen_Refund_NotFinalized() public {
        _presale(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert("Not finalized");
        ido.refund();
    }

    function test_RevertWhen_Refund_SucceededIdo() public {
        _presale(alice, ido.SOFT_CAP());
        _endAndFinalize();

        vm.prank(alice);
        vm.expectRevert("IDO succeeded");
        ido.refund();
    }

    function test_RevertWhen_Refund_NoContribution() public {
        vm.warp(ido.deadline());
        ido.finalize();

        vm.prank(alice);
        vm.expectRevert("No contribution");
        ido.refund();
    }

    function test_RevertWhen_Refund_Twice() public {
        _presale(alice, 50 ether);
        _endAndFinalize();

        vm.prank(alice);
        ido.refund();

        vm.prank(alice);
        vm.expectRevert("No contribution");
        ido.refund();
    }

    function test_Refund_ReentrancyCannotDrain() public {
        RefundAttacker attacker = new RefundAttacker(ido);
        vm.deal(address(attacker), 10 ether);
        vm.prank(address(attacker));
        attacker.buy{value: 10 ether}();
        _endAndFinalize();

        // 重入时 contribution 已清零，内层 refund 回退；外层 ETH 转账失败，整笔交易回滚
        vm.expectRevert("Refund failed");
        attacker.attack();
        assertEq(ido.contributions(address(attacker)), 10 ether);
        assertEq(address(ido).balance, 10 ether);

        attacker.refundHonest();
        assertEq(ido.contributions(address(attacker)), 0);
        assertEq(address(attacker).balance, 10 ether);
    }

    function test_WithdrawETH_OwnerReceivesRaisedFunds() public {
        _presale(alice, ido.SOFT_CAP());
        _endAndFinalize();

        uint256 ownerBefore = owner.balance;
        vm.prank(owner);
        ido.withdrawETH();

        assertEq(address(ido).balance, 0);
        assertEq(owner.balance, ownerBefore + ido.SOFT_CAP());
    }

    function test_RevertWhen_WithdrawETH_NotOwner() public {
        _presale(alice, ido.SOFT_CAP());
        _endAndFinalize();

        vm.prank(alice);
        vm.expectRevert("Not owner");
        ido.withdrawETH();
    }

    function test_RevertWhen_WithdrawETH_NotFinalizedOrFailed() public {
        _presale(alice, 50 ether);

        vm.prank(owner);
        vm.expectRevert("Not allowed");
        ido.withdrawETH();

        _endAndFinalize();

        vm.prank(owner);
        vm.expectRevert("Not allowed");
        ido.withdrawETH();
    }

    function test_WithdrawUnsoldTokens_ReturnsRemainderOnFailedSale() public {
        _presale(alice, 50 ether);
        _endAndFinalize();

        uint256 sold = (50 ether * 1e18) / ido.TOKEN_PRICE();
        uint256 unsold = ido.TOTAL_TOKENS() - sold;
        uint256 ownerBefore = token.balanceOf(owner);

        vm.prank(owner);
        ido.withdrawUnsoldTokens();

        assertEq(token.balanceOf(owner), ownerBefore + unsold);
        assertEq(token.balanceOf(address(ido)), sold);
    }

    function test_WithdrawUnsoldTokens_NoOpWhenFullySold() public {
        _presale(alice, ido.SOFT_CAP());
        _endAndFinalize();

        uint256 ownerBefore = token.balanceOf(owner);
        vm.prank(owner);
        ido.withdrawUnsoldTokens();

        assertEq(token.balanceOf(owner), ownerBefore);
        assertEq(token.balanceOf(address(ido)), ido.TOTAL_TOKENS());
    }

    function test_RevertWhen_WithdrawUnsoldTokens_NotOwner() public {
        vm.warp(ido.deadline());
        ido.finalize();

        vm.prank(alice);
        vm.expectRevert("Not owner");
        ido.withdrawUnsoldTokens();
    }

    function test_RevertWhen_WithdrawUnsoldTokens_NotFinalized() public {
        vm.prank(owner);
        vm.expectRevert("Not finalized");
        ido.withdrawUnsoldTokens();
    }

    function testFuzz_Claim_TokenAmountMatchesContribution(uint256 aliceAmount) public {
        uint256 min = ido.MIN_CONTRIBUTION();
        uint256 softCap = ido.SOFT_CAP();
        aliceAmount = bound(aliceAmount, min, softCap);
        if (aliceAmount < softCap && softCap - aliceAmount < min) {
            aliceAmount = softCap;
        }

        _presale(alice, aliceAmount);
        if (aliceAmount < softCap) {
            _presale(bob, softCap - aliceAmount);
        }
        _endAndFinalize();

        vm.prank(alice);
        ido.claim();

        assertEq(token.balanceOf(alice), (aliceAmount * 1e18) / ido.TOKEN_PRICE());
    }

    function testFuzz_Presale_RecordsAnyValidContribution(uint96 amount) public {
        amount = uint96(bound(amount, ido.MIN_CONTRIBUTION(), ido.HARD_CAP()));
        _presale(alice, amount);

        assertEq(ido.contributions(alice), amount);
        assertEq(ido.totalRaised(), amount);
        assertEq(address(ido).balance, amount);
    }
}
