// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {LogTriggeredCounter} from "../../src/chainlink_automation/log_trigger/LogTriggeredCounter.sol";
import {Log} from "../../src/chainlink_automation/interfaces/ILogAutomation.sol";

contract LogTriggeredCounterTest is Test {
    LogTriggeredCounter internal counter;
    address internal alice = makeAddr("alice");

    function setUp() public {
        counter = new LogTriggeredCounter();
    }

    function _fakeBumpedLog(address who, bytes32 txHash, uint256 index) internal view returns (Log memory log) {
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = counter.BUMPED_TOPIC();
        topics[1] = bytes32(uint256(uint160(who)));

        log = Log({
            index: index,
            timestamp: block.timestamp,
            txHash: txHash,
            blockNumber: block.number,
            // 合约逻辑不用 blockHash；单测随便填非零占位即可（非真实区块哈希）
            blockHash: bytes32(uint256(2)),
            source: address(counter),
            topics: topics,
            data: ""
        });
    }

    function test_bumpEmitsBumped() public {
        vm.expectEmit(true, false, false, false, address(counter));
        emit LogTriggeredCounter.Bumped(alice);
        vm.prank(alice);
        counter.bump();
    }

    function test_checkLogAndPerformUpkeep() public {
        Log memory log = _fakeBumpedLog(alice, bytes32(uint256(1)), 0);

        (bool needed, bytes memory performData) = counter.checkLog(log, "");
        assertTrue(needed);
        (address who, bytes32 txHash, uint256 logIndex) = abi.decode(performData, (address, bytes32, uint256));
        assertEq(who, alice);
        assertEq(txHash, bytes32(uint256(1)));
        assertEq(logIndex, 0);

        counter.performUpkeep(performData);
        assertEq(counter.hits(alice), 1);
        assertEq(counter.counter(), 1);
        assertTrue(counter.processedLog(keccak256(abi.encode(txHash, logIndex))));
    }

    function test_checkLogReturnsFalseOnWrongTopic() public view {
        Log memory log = _fakeBumpedLog(alice, bytes32(uint256(1)), 0);
        log.topics[0] = keccak256("Nope(address)");
        (bool needed,) = counter.checkLog(log, "");
        assertFalse(needed);
    }

    function test_checkLogReturnsFalseOnWrongSource() public view {
        Log memory log = _fakeBumpedLog(alice, bytes32(uint256(1)), 0);
        log.source = address(0xBEEF);
        (bool needed,) = counter.checkLog(log, "");
        assertFalse(needed);
    }

    function test_performUpkeepRevertsOnZeroAddress() public {
        vm.expectRevert(LogTriggeredCounter.BadPerformData.selector);
        counter.performUpkeep(abi.encode(address(0), bytes32(uint256(1)), uint256(0)));
    }

    function test_performUpkeepRevertsOnReplay() public {
        bytes memory performData = abi.encode(alice, bytes32(uint256(1)), uint256(0));
        counter.performUpkeep(performData);
        vm.expectRevert(LogTriggeredCounter.AlreadyProcessed.selector);
        counter.performUpkeep(performData);
    }

    function test_performUpkeepRevertsOnWrongLength() public {
        vm.expectRevert(LogTriggeredCounter.BadPerformData.selector);
        counter.performUpkeep(abi.encode(alice));
    }
}
