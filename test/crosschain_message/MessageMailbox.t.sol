// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {MessageMailbox} from "../../src/crosschain_message/MessageMailbox.sol";
import {RemoteCounter} from "../../src/crosschain_message/RemoteCounter.sol";

contract MessageMailboxTest is Test {
    uint64 internal constant HOME = 1;
    uint64 internal constant REMOTE = 2;
    uint256 internal constant DELTA = 7;

    address internal owner = makeAddr("owner");
    address internal relayer = makeAddr("relayer");
    address internal alice = makeAddr("alice");

    MessageMailbox internal srcMailbox;
    MessageMailbox internal destMailbox;
    RemoteCounter internal counter;

    function _deliver(address sender, bytes memory payload, uint64 nonce) internal {
        vm.prank(relayer);
        destMailbox.deliver(HOME, REMOTE, nonce, sender, address(counter), payload);
    }

    function setUp() public {
        srcMailbox = new MessageMailbox(HOME, REMOTE, relayer, owner);
        destMailbox = new MessageMailbox(REMOTE, HOME, relayer, owner);
        counter = new RemoteCounter(address(destMailbox));
    }

    function test_dispatchThenDeliverIncrementsCounter() public {
        bytes memory payload = abi.encode(DELTA);

        vm.prank(alice);
        bytes32 id = srcMailbox.dispatch(REMOTE, address(counter), payload);

        assertEq(srcMailbox.s_nonce(), 1);
        assertEq(id, srcMailbox.computeMessageId(HOME, REMOTE, 1, alice, address(counter), payload));
        assertEq(counter.s_count(), 0);

        _deliver(alice, payload, 1);

        assertEq(counter.s_count(), DELTA);
        assertEq(counter.s_lastSrcDomain(), HOME);
        assertEq(counter.s_lastSender(), alice);
    }

    function test_relayerNeverDeliversCounterUnchanged() public {
        vm.prank(alice);
        srcMailbox.dispatch(REMOTE, address(counter), abi.encode(DELTA));

        assertEq(counter.s_count(), 0);
        assertEq(
            destMailbox.s_processed(
                destMailbox.computeMessageId(HOME, REMOTE, 1, alice, address(counter), abi.encode(DELTA))
            ),
            false
        );
    }

    function test_RevertWhen_DeliverNotRelayer() public {
        bytes memory payload = abi.encode(DELTA);
        vm.prank(alice);
        srcMailbox.dispatch(REMOTE, address(counter), payload);

        vm.expectRevert(MessageMailbox.NotRelayer.selector);
        destMailbox.deliver(HOME, REMOTE, 1, alice, address(counter), payload);
    }

    function test_RevertWhen_ReplayDeliver() public {
        bytes memory payload = abi.encode(DELTA);
        vm.prank(alice);
        srcMailbox.dispatch(REMOTE, address(counter), payload);
        _deliver(alice, payload, 1);

        bytes32 messageId = destMailbox.computeMessageId(HOME, REMOTE, 1, alice, address(counter), payload);
        vm.expectRevert(abi.encodeWithSelector(MessageMailbox.AlreadyProcessed.selector, messageId));
        _deliver(alice, payload, 1);
    }

    function test_RevertWhen_HandleNotMailbox() public {
        vm.prank(alice);
        vm.expectRevert(RemoteCounter.NotMailbox.selector);
        counter.handle(HOME, alice, abi.encode(DELTA));
    }

    function test_RevertWhen_DispatchWrongDestDomain() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MessageMailbox.InvalidDestDomain.selector, HOME));
        srcMailbox.dispatch(HOME, address(counter), abi.encode(DELTA));
    }

    function test_RevertWhen_DeliverWrongDestDomain() public {
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(MessageMailbox.InvalidDestDomain.selector, HOME));
        destMailbox.deliver(HOME, HOME, 1, alice, address(counter), abi.encode(DELTA));
    }

    function test_RevertWhen_EmptyPayloadDispatch() public {
        vm.prank(alice);
        vm.expectRevert(MessageMailbox.EmptyPayload.selector);
        srcMailbox.dispatch(REMOTE, address(counter), "");
    }

    function test_RevertWhen_EmptyPayloadDeliver() public {
        vm.prank(relayer);
        vm.expectRevert(MessageMailbox.EmptyPayload.selector);
        destMailbox.deliver(HOME, REMOTE, 1, alice, address(counter), "");
    }

    function test_RevertWhen_RecipientNotContract() public {
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(MessageMailbox.RecipientNotContract.selector, alice));
        destMailbox.deliver(HOME, REMOTE, 1, alice, alice, abi.encode(DELTA));
    }

    function test_RevertWhen_UnknownSourceDomain() public {
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(MessageMailbox.UnknownSourceDomain.selector, uint64(99)));
        destMailbox.deliver(99, REMOTE, 1, alice, address(counter), abi.encode(DELTA));
    }

    function test_twoMessagesAccumulate() public {
        vm.prank(alice);
        srcMailbox.dispatch(REMOTE, address(counter), abi.encode(uint256(3)));
        _deliver(alice, abi.encode(uint256(3)), 1);

        vm.prank(alice);
        srcMailbox.dispatch(REMOTE, address(counter), abi.encode(uint256(4)));
        _deliver(alice, abi.encode(uint256(4)), 2);

        assertEq(counter.s_count(), 7);
    }

    function test_twoIdenticalPayloadsUseDistinctNonces() public {
        bytes memory payload = abi.encode(DELTA);

        vm.prank(alice);
        bytes32 first = srcMailbox.dispatch(REMOTE, address(counter), payload);
        vm.prank(alice);
        bytes32 second = srcMailbox.dispatch(REMOTE, address(counter), payload);

        assertEq(srcMailbox.s_nonce(), 2);
        assertEq(first, srcMailbox.computeMessageId(HOME, REMOTE, 1, alice, address(counter), payload));
        assertEq(second, srcMailbox.computeMessageId(HOME, REMOTE, 2, alice, address(counter), payload));
        assertTrue(first != second);

        _deliver(alice, payload, 1);
        _deliver(alice, payload, 2);
        assertEq(counter.s_count(), DELTA * 2);
    }
}
