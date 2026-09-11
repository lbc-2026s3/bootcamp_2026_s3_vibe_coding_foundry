// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public stranger = makeAddr("stranger");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = alice;
        owners[1] = bob;
        owners[2] = carol;
        // 默认 2/3
        wallet = new MultiSigWallet(owners, 2);
        vm.deal(address(wallet), 10 ether);
    }

    function test_Constructor_SetsOwnersAndThreshold() public view {
        assertEq(wallet.threshold(), 2);
        assertTrue(wallet.isOwner(alice));
        assertTrue(wallet.isOwner(bob));
        assertTrue(wallet.isOwner(carol));
        assertFalse(wallet.isOwner(stranger));

        address[] memory owners = wallet.getOwners();
        assertEq(owners.length, 3);
        assertEq(owners[0], alice);
        assertEq(owners[1], bob);
        assertEq(owners[2], carol);
    }

    function test_RevertWhen_InvalidThreshold() public {
        address[] memory owners = new address[](3);
        owners[0] = alice;
        owners[1] = bob;
        owners[2] = carol;

        vm.expectRevert(MultiSigWallet.InvalidThreshold.selector);
        new MultiSigWallet(owners, 0);

        vm.expectRevert(MultiSigWallet.InvalidThreshold.selector);
        new MultiSigWallet(owners, 4);
    }

    function test_RevertWhen_DuplicateOrZeroOwner() public {
        address[] memory dup = new address[](2);
        dup[0] = alice;
        dup[1] = alice;
        vm.expectRevert(MultiSigWallet.InvalidOwners.selector);
        new MultiSigWallet(dup, 1);

        address[] memory zero = new address[](1);
        zero[0] = address(0);
        vm.expectRevert(MultiSigWallet.InvalidOwners.selector);
        new MultiSigWallet(zero, 1);
    }

    function test_Propose_OwnerAutoConfirms() public {
        vm.prank(alice);
        uint256 id = wallet.propose(recipient, 1 ether, "");

        assertEq(id, 0);
        assertEq(wallet.proposalCount(), 1);
        assertTrue(wallet.isConfirmed(id, alice));

        (address to, uint256 value, bytes memory data, uint256 confirmations, bool executed) = wallet.getProposal(id);
        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(data.length, 0);
        assertEq(confirmations, 1);
        assertFalse(executed);
    }

    function test_RevertWhen_NonOwnerProposes() public {
        vm.prank(stranger);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        wallet.propose(recipient, 1 ether, "");
    }

    function test_Confirm_IncrementsConfirmations() public {
        vm.prank(alice);
        uint256 id = wallet.propose(recipient, 1 ether, "");

        vm.prank(bob);
        wallet.confirm(id);

        (,,, uint256 confirmations,) = wallet.getProposal(id);
        assertEq(confirmations, 2);
        assertTrue(wallet.isConfirmed(id, bob));
    }

    function test_RevertWhen_DoubleConfirm() public {
        vm.prank(alice);
        uint256 id = wallet.propose(recipient, 1 ether, "");

        vm.prank(alice);
        vm.expectRevert(MultiSigWallet.AlreadyConfirmed.selector);
        wallet.confirm(id);
    }

    function test_RevertWhen_NonOwnerConfirms() public {
        vm.prank(alice);
        uint256 id = wallet.propose(recipient, 1 ether, "");

        vm.prank(stranger);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        wallet.confirm(id);
    }

    function test_Execute_AnyoneCanExecuteAfterThreshold() public {
        vm.prank(alice);
        uint256 id = wallet.propose(recipient, 1 ether, "");

        vm.prank(bob);
        wallet.confirm(id);

        uint256 balBefore = recipient.balance;
        // 非 owner 也可以执行
        vm.prank(stranger);
        wallet.execute(id);

        assertEq(recipient.balance, balBefore + 1 ether);
        (,,,, bool executed) = wallet.getProposal(id);
        assertTrue(executed);
    }

    function test_RevertWhen_ExecuteBeforeThreshold() public {
        vm.prank(alice);
        uint256 id = wallet.propose(recipient, 1 ether, "");

        vm.expectRevert(MultiSigWallet.NotEnoughConfirmations.selector);
        wallet.execute(id);
    }

    function test_RevertWhen_ExecuteTwice() public {
        vm.prank(alice);
        uint256 id = wallet.propose(recipient, 1 ether, "");
        vm.prank(bob);
        wallet.confirm(id);

        wallet.execute(id);

        vm.expectRevert(MultiSigWallet.AlreadyExecuted.selector);
        wallet.execute(id);
    }

    function test_Execute_WithCalldata() public {
        Target target = new Target();

        vm.prank(alice);
        uint256 id = wallet.propose(address(target), 0, abi.encodeCall(Target.set, (42)));
        vm.prank(carol);
        wallet.confirm(id);

        wallet.execute(id);
        assertEq(target.value(), 42);
    }

    function test_Receive_AcceptsEth() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok,) = address(wallet).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(wallet).balance, 11 ether);
    }

    function test_FullFlow_2of3_EthTransfer() public {
        vm.prank(bob);
        uint256 id = wallet.propose(recipient, 2.5 ether, "");

        // 仅 1 票，不可执行
        vm.expectRevert(MultiSigWallet.NotEnoughConfirmations.selector);
        wallet.execute(id);

        // carol 确认后达到 2/3
        vm.prank(carol);
        wallet.confirm(id);

        wallet.execute(id);
        assertEq(recipient.balance, 2.5 ether);
    }
}

contract Target {
    uint256 public value;

    function set(uint256 v) external {
        value = v;
    }
}
