// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {HeartbeatCounter} from "../../src/chainlink_automation/heartbeat/HeartbeatCounter.sol";

contract HeartbeatCounterTest is Test {
    HeartbeatCounter internal counter;

    function setUp() public {
        counter = new HeartbeatCounter();
    }

    function test_pulseIncrementsAndRecordsTimestamp() public {
        vm.warp(1_700_000_000);
        counter.pulse();
        assertEq(counter.counter(), 1);
        assertEq(counter.lastPulseAt(), 1_700_000_000);

        vm.warp(1_700_000_300);
        counter.pulse();
        assertEq(counter.counter(), 2);
        assertEq(counter.lastPulseAt(), 1_700_000_300);
    }
}
