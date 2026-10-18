// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {EventLab} from "../../src/events/EventLab.sol";

contract EventLabTest is Test {
    EventLab internal lab;

    function setUp() public {
        lab = new EventLab();
    }

    function test_valueTypesAreStoredRawInTopics() public {
        address account = address(0xBEEF);
        bytes32 tag = bytes32("tag");

        vm.recordLogs();
        lab.emitValueIndexed(42, account, tag, true);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics.length, 4);
        assertEq(logs[0].topics[1], bytes32(uint256(42)));
        assertEq(logs[0].topics[2], bytes32(uint256(uint160(account))));
        assertEq(logs[0].topics[3], tag);

        bool flag = abi.decode(logs[0].data, (bool));
        assertTrue(flag);
    }

    function test_dynamicIndexedTopicsAreContentHashes() public {
        string memory note = "hello indexed";
        bytes memory blob = hex"cafebabe";

        vm.recordLogs();
        lab.emitDynamicIndexed(note, blob);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs[0].topics.length, 3);
        assertEq(logs[0].topics[1], keccak256(bytes(note)));
        assertEq(logs[0].topics[2], keccak256(blob));

        (string memory decodedNote, bytes memory decodedBlob) = abi.decode(logs[0].data, (string, bytes));
        assertEq(decodedNote, note);
        assertEq(decodedBlob, blob);
    }

    function test_arrayAndStructIndexedTopicsAreSpecialEncodings() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;

        vm.recordLogs();
        lab.emitReferenceIndexed(ids, 7, "widget");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 expectedIds = keccak256(abi.encodePacked(uint256(1), uint256(2), uint256(3)));
        // 结构体成员各自补齐到 32 字节后拼接；string 右补齐，没有长度和 offset。
        bytes32 expectedItem = keccak256(abi.encodePacked(uint256(7), bytes32("widget")));

        assertEq(logs[0].topics.length, 3);
        assertEq(logs[0].topics[1], expectedIds);
        assertEq(logs[0].topics[2], expectedItem);

        (uint256[] memory decodedIds, EventLab.Item memory item) =
            abi.decode(logs[0].data, (uint256[], EventLab.Item));
        assertEq(decodedIds.length, 3);
        assertEq(decodedIds[0], 1);
        assertEq(decodedIds[2], 3);
        assertEq(item.id, 7);
        assertEq(item.name, "widget");
    }

    function test_anonymousEventOmitsSignatureTopic() public {
        address account = address(0xBEEF);
        bytes32 tag = bytes32("tag");
        bytes32 signature = keccak256("AnonymousIndexed(address,uint256,bytes32,bool)");

        vm.recordLogs();
        lab.emitAnonymousIndexed(account, 42, tag, true);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics.length, 4);
        assertTrue(logs[0].topics[0] != signature);
        assertEq(logs[0].topics[0], bytes32(uint256(uint160(account))));
        assertEq(logs[0].topics[1], bytes32(uint256(42)));
        assertEq(logs[0].topics[2], tag);
        assertEq(logs[0].topics[3], bytes32(uint256(1)));
        assertEq(logs[0].data.length, 0);
    }

    function test_emitSampleEmitsAllLogs() public {
        vm.recordLogs();
        lab.emitSample();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 4);
        assertEq(logs[0].topics[1], bytes32(uint256(lab.SAMPLE_AMOUNT())));
        assertEq(logs[1].topics[1], keccak256(bytes(lab.SAMPLE_NOTE())));
        assertEq(logs[1].topics[2], keccak256(lab.SAMPLE_BLOB()));
        assertEq(logs[3].topics[0], bytes32(uint256(uint160(address(this)))));
        assertEq(logs[3].topics.length, 4);
    }
}
