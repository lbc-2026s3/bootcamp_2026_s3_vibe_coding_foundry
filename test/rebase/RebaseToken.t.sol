// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/rebase/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken internal token;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    event Rebase(uint256 yearsApplied, uint256 previousSupply, uint256 newSupply);

    function setUp() public {
        token = new RebaseToken(alice);
    }

    function test_InitialSupplyAndBalance() public view {
        assertEq(token.totalSupply(), 1_000_000 ether);
        assertEq(token.balanceOf(alice), 1_000_000 ether);
        assertEq(token.sharesOf(alice), 1_000_000 ether);
        assertEq(token.rebaseCount(), 0);
    }

    function test_TokenSharesConversion() public {
        // 初始 1:1
        assertEq(token.tokenToShares(100 ether), 100 ether);
        assertEq(token.sharesToToken(100 ether), 100 ether);

        vm.warp(block.timestamp + token.YEAR());
        token.rebase();

        // rebase 后：同样 100 token 对应更多份额；同样份额对应更少 token
        assertGt(token.tokenToShares(100 ether), 100 ether);
        assertLt(token.sharesToToken(100 ether), 100 ether);

        assertEq(token.sharesToToken(token.sharesOf(alice)), token.balanceOf(alice));
        assertEq(token.tokenToShares(token.balanceOf(alice)), token.sharesOf(alice));
    }

    function test_RevertWhen_RebaseBeforeOneYear() public {
        vm.expectRevert(
            abi.encodeWithSelector(RebaseToken.RebaseTooEarly.selector, token.nextRebaseTimestamp())
        );
        token.rebase();
    }

    function test_RebaseDeflatesSupplyAndBalanceByOnePercent() public {
        uint256 beforeSupply = token.totalSupply();
        uint256 beforeBal = token.balanceOf(alice);
        uint256 beforeShares = token.sharesOf(alice);

        vm.warp(block.timestamp + token.YEAR());

        vm.expectEmit(true, true, true, true);
        emit Rebase(1, beforeSupply, (beforeSupply * 99) / 100);

        (uint256 yearsApplied, uint256 newSupply) = token.rebase();

        assertEq(yearsApplied, 1);
        assertEq(newSupply, (beforeSupply * 99) / 100);
        assertEq(token.totalSupply(), newSupply);
        assertEq(token.balanceOf(alice), (beforeBal * 99) / 100);
        // 份额不变，余额随供给缩放
        assertEq(token.sharesOf(alice), beforeShares);
        assertEq(token.rebaseCount(), 1);
    }

    function test_RebaseCatchUpMultipleYears() public {
        vm.warp(block.timestamp + 3 * token.YEAR());

        uint256 expected = 1_000_000 ether;
        expected = (expected * 99) / 100;
        expected = (expected * 99) / 100;
        expected = (expected * 99) / 100;

        (uint256 yearsApplied, uint256 newSupply) = token.rebase();

        assertEq(yearsApplied, 3);
        assertEq(newSupply, expected);
        assertEq(token.balanceOf(alice), expected);
        assertEq(token.rebaseCount(), 3);
    }

    function test_BalanceOfReflectsRebaseAfterTransfer() public {
        vm.prank(alice);
        token.transfer(bob, 400_000 ether);

        assertEq(token.balanceOf(alice), 600_000 ether);
        assertEq(token.balanceOf(bob), 400_000 ether);

        vm.warp(block.timestamp + token.YEAR());
        token.rebase();

        assertEq(token.balanceOf(alice), (600_000 ether * 99) / 100);
        assertEq(token.balanceOf(bob), (400_000 ether * 99) / 100);
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), token.totalSupply());
    }

    function test_TransferEntireBalanceLeavesNoDustShares() public {
        uint256 amount = token.balanceOf(alice);
        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.sharesOf(alice), 0);
        assertEq(token.balanceOf(bob), token.totalSupply());
    }

    function test_RevertWhen_TransferExceedsBalance() public {
        vm.prank(alice);
        token.transfer(bob, 1 ether);

        vm.prank(bob);
        vm.expectRevert();
        token.transfer(alice, 2 ether);
    }

    function test_RevertWhen_PostRebaseMicroTransferCreatesDust() public {
        vm.warp(block.timestamp + token.YEAR());
        token.rebase();

        // rebase 后 1 wei 会分到份额但收款人 balanceOf 仍为 0
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RebaseToken.TransferTooSmall.selector, 1));
        token.transfer(bob, 1);
    }

    function test_RevertWhen_RebaseTwiceInSameYear() public {
        vm.warp(block.timestamp + token.YEAR());
        token.rebase();

        vm.expectRevert(
            abi.encodeWithSelector(RebaseToken.RebaseTooEarly.selector, token.nextRebaseTimestamp())
        );
        token.rebase();
    }

    function test_RevertWhen_ConstructorZeroRecipient() public {
        vm.expectRevert(RebaseToken.ZeroAddress.selector);
        new RebaseToken(address(0));
    }

    function testFuzz_RebasePreservesShareRatios(uint256 bobAmount, uint8 yearsElapsed) public {
        bobAmount = bound(bobAmount, 1, 999_999 ether);
        yearsElapsed = uint8(bound(yearsElapsed, 1, 50));

        vm.prank(alice);
        token.transfer(bob, bobAmount);

        uint256 aliceShares = token.sharesOf(alice);
        uint256 bobShares = token.sharesOf(bob);
        uint256 totalShares = token.totalShares();

        vm.warp(block.timestamp + uint256(yearsElapsed) * token.YEAR());
        token.rebase();

        assertEq(token.sharesOf(alice), aliceShares);
        assertEq(token.sharesOf(bob), bobShares);
        assertEq(token.totalShares(), totalShares);

        assertEq(token.balanceOf(alice), (aliceShares * token.totalSupply()) / totalShares);
        assertEq(token.balanceOf(bob), (bobShares * token.totalSupply()) / totalShares);
        assertLe(token.balanceOf(alice) + token.balanceOf(bob), token.totalSupply());
    }
}
