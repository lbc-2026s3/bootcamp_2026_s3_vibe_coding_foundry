// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {ArmedCounter} from "../../src/chainlink_automation/armed/ArmedCounter.sol";

contract ArmedCounterTest is Test {
    ArmedCounter internal counter;

    function setUp() public {
        counter = new ArmedCounter();
    }

    function test_checkUpkeepFalseUntilArmed() public {
        (bool needed,) = counter.checkUpkeep("");
        assertFalse(needed);

        counter.arm();
        (needed,) = counter.checkUpkeep("");
        assertTrue(needed);
    }

    function test_performUpkeepOnceThenDisarms() public {
        counter.arm();
        assertTrue(counter.armed());
        counter.performUpkeep("");
        assertEq(counter.counter(), 1);
        assertFalse(counter.armed());

        (bool needed,) = counter.checkUpkeep("");
        assertFalse(needed);
    }

    function test_performUpkeepRevertsWhenNotArmed() public {
        vm.expectRevert(ArmedCounter.NotArmed.selector);
        counter.performUpkeep("");
    }

    function test_rearmAllowsAnotherPerform() public {
        counter.arm();
        assertTrue(counter.armed());
        counter.performUpkeep("");
        counter.arm();
        assertTrue(counter.armed());
        counter.performUpkeep("");
        assertEq(counter.counter(), 2);
        assertFalse(counter.armed());
    }
}
