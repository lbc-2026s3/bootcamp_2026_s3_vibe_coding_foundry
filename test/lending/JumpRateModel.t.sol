// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {JumpRateModel} from "../../src/lending/JumpRateModel.sol";

contract JumpRateModelTest is Test {
    uint256 internal constant SECONDS_PER_YEAR = 365 days;
    uint256 internal constant BASE_APR = 0.02e18;
    uint256 internal constant MULTIPLIER_APR = 0.10e18;
    uint256 internal constant JUMP_MULTIPLIER_APR = 4.5e18;
    uint256 internal constant KINK = 0.80e18;

    JumpRateModel internal model;

    function setUp() public {
        model = new JumpRateModel(
            BASE_APR / SECONDS_PER_YEAR, MULTIPLIER_APR / SECONDS_PER_YEAR, JUMP_MULTIPLIER_APR / SECONDS_PER_YEAR, KINK
        );
    }

    function test_borrowRateAtZeroUtilization() public view {
        assertEq(model.getBorrowRate(100e18, 0, 0), BASE_APR / SECONDS_PER_YEAR);
    }

    function test_borrowRateAtKink() public view {
        // 800 / 1000 = 80%
        uint256 rate = model.getBorrowRate(200e18, 800e18, 0);
        uint256 base = BASE_APR / SECONDS_PER_YEAR;
        uint256 multiplier = MULTIPLIER_APR / SECONDS_PER_YEAR;
        assertEq(rate, base + KINK * multiplier / 1e18);
    }

    function test_borrowRateAtFullUtilization() public view {
        uint256 rate = model.getBorrowRate(0, 100e18, 0);
        uint256 base = BASE_APR / SECONDS_PER_YEAR;
        uint256 multiplier = MULTIPLIER_APR / SECONDS_PER_YEAR;
        uint256 jump = JUMP_MULTIPLIER_APR / SECONDS_PER_YEAR;
        uint256 normal = base + KINK * multiplier / 1e18;
        assertEq(rate, normal + (1e18 - KINK) * jump / 1e18);
    }

    function test_rateAboveKinkIsHigherThanAtKink() public view {
        uint256 atKink = model.getBorrowRate(200e18, 800e18, 0);
        uint256 atNinety = model.getBorrowRate(100e18, 900e18, 0);
        assertGt(atNinety, atKink);
    }

    function test_slopeAboveKinkIsSteeper() public view {
        uint256 atZero = model.getBorrowRate(100e18, 0, 0);
        uint256 atKink = model.getBorrowRate(200e18, 800e18, 0);
        uint256 atFull = model.getBorrowRate(0, 100e18, 0);

        uint256 below = (atKink - atZero) * 1e18 / KINK;
        uint256 above = (atFull - atKink) * 1e18 / (1e18 - KINK);
        assertGt(above, below);
    }

    function test_supplyRateKeepsLenderShare() public view {
        uint256 borrowRate = model.getBorrowRate(200e18, 800e18, 0);
        uint256 util = model.utilizationRate(200e18, 800e18, 0);
        uint256 reserveFactor = 0.10e18;
        uint256 expected = borrowRate * util / 1e18 * (1e18 - reserveFactor) / 1e18;
        assertEq(model.getSupplyRate(200e18, 800e18, 0, reserveFactor), expected);
        assertLt(expected, borrowRate);
    }

    function test_zeroKinkReverts() public {
        vm.expectRevert(JumpRateModel.InvalidKink.selector);
        new JumpRateModel(0, 0, 0, 0);
    }
}
