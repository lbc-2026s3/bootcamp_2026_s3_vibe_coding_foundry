// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {LuckyDraw} from "../../src/chainlink_vrf/LuckyDraw.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

contract LuckyDrawTest is Test {
    VRFCoordinatorV2_5Mock internal coordinator;
    LuckyDraw internal draw;

    bytes32 internal constant KEY_HASH = hex"787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae";
    uint32 internal constant CALLBACK_GAS_LIMIT = 100_000;

    address internal player = makeAddr("player");
    address internal player2 = makeAddr("player2");
    uint256 internal subId;

    function setUp() public {
        coordinator = new VRFCoordinatorV2_5Mock(0.002 ether, 40 gwei, 0.004 ether);
        subId = coordinator.createSubscription();
        coordinator.fundSubscription(subId, 100 ether);

        draw = new LuckyDraw(address(coordinator), subId, KEY_HASH, CALLBACK_GAS_LIMIT);
        coordinator.addConsumer(subId, address(draw));
    }

    function test_enterDrawSetsPendingAndRequestId() public {
        vm.prank(player);
        uint256 requestId = draw.enterDraw();

        assertTrue(requestId != 0);
        assertEq(draw.getPendingRequest(player), requestId);
        assertEq(draw.s_requestToPlayer(requestId), player);

        vm.expectRevert(LuckyDraw.StillPending.selector);
        draw.getTicket(player);
    }

    function test_fulfillWritesTicketInRangeAndClearsPending() public {
        vm.prank(player);
        uint256 requestId = draw.enterDraw();

        uint256[] memory words = new uint256[](1);
        words[0] = 142; // (142 % 100) + 1 = 43
        coordinator.fulfillRandomWordsWithOverride(requestId, address(draw), words);

        assertEq(draw.getPendingRequest(player), 0);
        assertEq(draw.s_requestToPlayer(requestId), address(0));
        assertEq(draw.getTicket(player), 43);
        assertGe(draw.s_tickets(player), 1);
        assertLe(draw.s_tickets(player), 100);
    }

    function test_secondEnterDrawRevertsAfterResult() public {
        vm.prank(player);
        uint256 requestId = draw.enterDraw();
        coordinator.fulfillRandomWords(requestId, address(draw));

        vm.prank(player);
        vm.expectRevert(LuckyDraw.AlreadyDrawn.selector);
        draw.enterDraw();
    }

    function test_secondEnterDrawRevertsWhilePending() public {
        vm.prank(player);
        draw.enterDraw();

        vm.prank(player);
        vm.expectRevert(LuckyDraw.DrawPending.selector);
        draw.enterDraw();
    }

    function test_nonCoordinatorCannotFulfill() public {
        vm.prank(player);
        uint256 requestId = draw.enterDraw();

        uint256[] memory words = new uint256[](1);
        words[0] = 1;

        vm.expectRevert(
            abi.encodeWithSelector(VRFConsumerBaseV2Plus.OnlyCoordinatorCanFulfill.selector, address(this), address(coordinator))
        );
        draw.rawFulfillRandomWords(requestId, words);
    }

    function test_getTicketRevertsWhenNeverEntered() public {
        vm.expectRevert(LuckyDraw.NoTicket.selector);
        draw.getTicket(player);
    }

    function test_twoPlayersParallelDraws() public {
        vm.prank(player);
        uint256 requestId1 = draw.enterDraw();
        vm.prank(player2);
        uint256 requestId2 = draw.enterDraw();

        assertTrue(requestId1 != 0);
        assertTrue(requestId2 != 0);
        assertTrue(requestId1 != requestId2);

        uint256[] memory words1 = new uint256[](1);
        words1[0] = 7; // ticket 8
        uint256[] memory words2 = new uint256[](1);
        words2[0] = 99; // ticket 100

        coordinator.fulfillRandomWordsWithOverride(requestId1, address(draw), words1);
        coordinator.fulfillRandomWordsWithOverride(requestId2, address(draw), words2);

        assertEq(draw.getTicket(player), 8);
        assertEq(draw.getTicket(player2), 100);
        assertEq(draw.getPendingRequest(player), 0);
        assertEq(draw.getPendingRequest(player2), 0);
    }
}
