// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VestingWallet} from "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";
import {TokenVesting} from "../src/TokenVesting.sol";

contract TokenVestingTest is Test {
    MyTokenV1 public token;
    TokenVesting public vesting;

    address public owner = makeAddr("owner");
    address public beneficiary = makeAddr("beneficiary");
    address public attacker = makeAddr("attacker");

    uint256 public constant TOTAL = 1_000_000e18;
    uint256 public constant CLIFF = 12 * 30 days;
    uint256 public constant VESTING = 24 * 30 days;

    function setUp() public {
        vm.startPrank(owner);
        token = new MyTokenV1();
        vesting = new TokenVesting(address(token), beneficiary);
        token.transfer(address(vesting), token.INITIAL_SUPPLY());
        vm.stopPrank();
    }

    // ---------- 构造器 ----------

    function test_Constructor_SetsBeneficiaryTokenAndSchedule() public view {
        assertEq(vesting.owner(), beneficiary);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.start(), block.timestamp);
        assertEq(vesting.duration(), CLIFF + VESTING);
        assertEq(vesting.end(), vesting.start() + CLIFF + VESTING);
        assertEq(vesting.CLIFF_DURATION(), CLIFF);
        assertEq(vesting.VESTING_DURATION(), VESTING);
        assertEq(token.balanceOf(address(vesting)), TOTAL);
    }

    function test_RevertWhen_Constructor_ZeroToken() public {
        vm.expectRevert("Invalid token");
        new TokenVesting(address(0), beneficiary);
    }

    // ---------- Cliff 期间（前 12 个月）不可释放 ----------

    function test_Releasable_ZeroDuringCliff() public {
        vm.warp(vesting.start() + CLIFF - 1);
        assertEq(vesting.releasable(address(token)), 0);
        assertEq(vesting.vestedAmount(address(token), uint64(block.timestamp)), 0);
    }

    function test_Releasable_ZeroAtCliffEnd() public {
        vm.warp(vesting.start() + CLIFF);
        assertEq(vesting.releasable(address(token)), 0);
    }

    function test_Release_DuringCliff_TransfersNothing() public {
        vm.warp(vesting.start() + 6 * 30 days);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), 0);
        assertEq(vesting.released(address(token)), 0);
        assertEq(token.balanceOf(address(vesting)), TOTAL);
    }

    // ---------- 线性释放关键节点（模拟时间流逝） ----------

    function test_Releasable_LinearCheckpoints() public {
        // 第 13 个月末: 1/24
        vm.warp(vesting.start() + CLIFF + 30 days);
        assertEq(vesting.releasable(address(token)), TOTAL / 24);

        // 第 18 个月末: 6/24 = 1/4
        vm.warp(vesting.start() + CLIFF + 6 * 30 days);
        assertEq(vesting.releasable(address(token)), TOTAL / 4);

        // 第 24 个月末: 12/24 = 1/2
        vm.warp(vesting.start() + CLIFF + 12 * 30 days);
        assertEq(vesting.releasable(address(token)), TOTAL / 2);

        // 第 30 个月末: 18/24 = 3/4
        vm.warp(vesting.start() + CLIFF + 18 * 30 days);
        assertEq(vesting.releasable(address(token)), (3 * TOTAL) / 4);
    }

    function test_Release_AfterMonth13_TransfersOneTwentyFourth() public {
        vm.warp(vesting.start() + CLIFF + 30 days);
        uint256 expected = TOTAL / 24;

        vm.expectEmit(true, false, false, true);
        emit VestingWallet.ERC20Released(address(token), expected);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), expected);
        assertEq(vesting.released(address(token)), expected);
        assertEq(vesting.releasable(address(token)), 0);
        assertEq(token.balanceOf(address(vesting)), TOTAL - expected);
    }

    function test_Release_AfterFullVesting_TransfersAllTokens() public {
        vm.warp(vesting.end());
        assertEq(vesting.releasable(address(token)), TOTAL);

        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL);
        assertEq(vesting.released(address(token)), TOTAL);
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function test_Release_MultiplePartialReleases_Accumulate() public {
        vm.warp(vesting.start() + CLIFF + 30 days);
        vesting.release();

        vm.warp(vesting.start() + CLIFF + 2 * 30 days);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), (2 * TOTAL) / 24);
        assertEq(vesting.released(address(token)), (2 * TOTAL) / 24);
        assertEq(token.balanceOf(address(vesting)), TOTAL - (2 * TOTAL) / 24);
    }

    function test_Release_CalledByAnyone_SendsOnlyToBeneficiary() public {
        vm.warp(vesting.start() + CLIFF + 30 days);

        vm.prank(attacker);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL / 24);
        assertEq(token.balanceOf(attacker), 0);
    }

    // ---------- Fuzz：任意时刻的解锁量与公式逐点吻合 ----------

    function testFuzz_VestedAmount_MatchesSchedule(uint256 warpTo) public {
        uint256 startTs = vesting.start();
        uint256 maxTs = startTs + CLIFF + VESTING + 30 days;
        uint256 t = bound(warpTo, startTs, maxTs);
        vm.warp(t);

        uint256 expected;
        if (t <= startTs + CLIFF) {
            expected = 0;
        } else if (t >= startTs + CLIFF + VESTING) {
            expected = TOTAL;
        } else {
            expected = (TOTAL * (t - startTs - CLIFF)) / VESTING;
        }

        assertEq(vesting.vestedAmount(address(token), uint64(t)), expected);
    }

    function testFuzz_Release_TransfersExactlyReleasable(uint256 warpTo) public {
        uint256 startTs = vesting.start();
        uint256 maxTs = startTs + CLIFF + VESTING + 30 days;
        uint256 t = bound(warpTo, startTs, maxTs);
        vm.warp(t);

        uint256 beforeVestingBalance = token.balanceOf(address(vesting));
        uint256 beforeBeneficiaryBalance = token.balanceOf(beneficiary);
        uint256 releasable = vesting.releasable(address(token));

        vesting.release();

        assertEq(token.balanceOf(beneficiary), beforeBeneficiaryBalance + releasable);
        assertEq(token.balanceOf(address(vesting)), beforeVestingBalance - releasable);
    }
}
