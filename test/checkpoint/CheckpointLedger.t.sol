// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CheckpointLedger} from "../../src/checkpoint/CheckpointLedger.sol";

contract CheckpointLedgerTest is Test {
    CheckpointLedger internal ledger;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        ledger = new CheckpointLedger();
    }

    function test_MintWritesCheckpointAtCurrentBlock() public {
        uint256 blockAtMint = block.number;

        ledger.mint(alice, 100);

        assertEq(ledger.balanceOf(alice), 100);
        assertEq(ledger.totalSupply(), 100);
        assertEq(ledger.numCheckpoints(alice), 1);

        (uint48 key, uint208 value) = ledger.checkpointAt(alice, 0);
        assertEq(key, uint48(blockAtMint));
        assertEq(value, 100);
    }

    function test_BalanceOfAtReturnsHistoricalValue() public {
        // block N: mint 100
        uint256 b1 = block.number;
        ledger.mint(alice, 100);

        // block N+1: mint 50 more → balance 150
        vm.roll(b1 + 1);
        uint256 b2 = block.number;
        ledger.mint(alice, 50);

        // block N+2: transfer 30 to bob → alice 120
        vm.roll(b2 + 1);
        uint256 b3 = block.number;
        vm.prank(alice);
        ledger.transfer(bob, 30);

        assertEq(ledger.balanceOfAt(alice, b1), 100);
        assertEq(ledger.balanceOfAt(alice, b2), 150);
        assertEq(ledger.balanceOfAt(alice, b3), 120);
        assertEq(ledger.balanceOfAt(bob, b1), 0);
        assertEq(ledger.balanceOfAt(bob, b2), 0);
        assertEq(ledger.balanceOfAt(bob, b3), 30);

        // 查询中间未写入的区块：返回 ≤ 该区块的最近值
        assertEq(ledger.balanceOfAt(alice, b1), 100);
        assertEq(ledger.totalSupplyAt(b1), 100);
        assertEq(ledger.totalSupplyAt(b2), 150);
        assertEq(ledger.totalSupplyAt(b3), 150);
    }

    function test_SameBlockOverwriteDoesNotGrowLength() public {
        ledger.mint(alice, 10);
        ledger.mint(alice, 20); // 同区块覆盖

        assertEq(ledger.numCheckpoints(alice), 1);
        // 10 + 20 = 30
        assertEq(ledger.balanceOf(alice), 30);

        (uint48 key, uint208 value) = ledger.checkpointAt(alice, 0);
        assertEq(key, uint48(block.number));
        assertEq(value, 30);
    }

    function test_RevertWhen_BurnExceedsBalance() public {
        ledger.mint(alice, 10);

        vm.expectRevert(
            abi.encodeWithSelector(CheckpointLedger.InsufficientBalance.selector, alice, uint256(10), uint256(11))
        );
        ledger.burn(alice, 11);
    }

    function test_LatestCheckpoint() public {
        (bool existsBefore,,) = ledger.latestCheckpoint(alice);
        assertFalse(existsBefore);

        ledger.mint(alice, 7);

        (bool exists, uint48 key, uint208 value) = ledger.latestCheckpoint(alice);
        assertTrue(exists);
        assertEq(key, uint48(block.number));
        assertEq(value, 7);
    }
}
