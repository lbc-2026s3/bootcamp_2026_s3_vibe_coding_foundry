// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {OptionToken} from "../../src/option/OptionToken.sol";

/// @notice 6 decimals 的 USDT mock，贴近主网 USDT 精度（非 transfer 无返回值行为）
contract MockUSDT is ERC20 {
    constructor() ERC20("Tether USD", "USDT") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract OptionTokenTest is Test {
    OptionToken internal option;
    MockUSDT internal usdt;

    address internal issuer = makeAddr("issuer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    /// @dev 行权价：2000 USDT / ETH（6 decimals）
    uint256 internal constant STRIKE = 2000e6;
    uint256 internal expiry;

    event Issued(address indexed issuer, uint256 ethAmount, uint256 optionAmount);
    event Exercised(address indexed user, uint256 optionAmount, uint256 usdtPaid, uint256 ethReceived);
    event ExpiredAndRedeemed(address indexed issuer, uint256 optionsBurned, uint256 ethRedeemed);

    function setUp() public {
        usdt = new MockUSDT();
        expiry = block.timestamp + 7 days;

        option = new OptionToken("ETH Call 2000", "oETH-2000", address(usdt), STRIKE, expiry, issuer);

        vm.deal(issuer, 100 ether);
        usdt.mint(alice, 1_000_000e6);
        usdt.mint(bob, 1_000_000e6);
    }

    function _issueAndDistribute(uint256 ethAmount, address to, uint256 optionAmount) internal {
        vm.prank(issuer);
        option.issue{value: ethAmount}();

        if (to != issuer && optionAmount > 0) {
            vm.prank(issuer);
            option.transfer(to, optionAmount);
        }
    }

    function test_ConstructorSetsStrikeAndExpiry() public view {
        assertEq(address(option.usdt()), address(usdt));
        assertEq(option.strikePrice(), STRIKE);
        assertEq(option.expiry(), expiry);
        assertEq(option.owner(), issuer);
        assertEq(option.exerciseDeadline(), expiry + 1 days);
    }

    function test_RevertWhen_ConstructorInvalidExpiry() public {
        vm.expectRevert(OptionToken.InvalidExpiry.selector);
        new OptionToken("x", "x", address(usdt), STRIKE, block.timestamp, issuer);
    }

    function test_IssueMintsOneToOneWithEth() public {
        vm.expectEmit(true, true, true, true);
        emit Issued(issuer, 10 ether, 10 ether);

        vm.prank(issuer);
        option.issue{value: 10 ether}();

        assertEq(option.totalSupply(), 10 ether);
        assertEq(option.balanceOf(issuer), 10 ether);
        assertEq(address(option).balance, 10 ether);
    }

    function test_RevertWhen_NonIssuerIssues() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert();
        option.issue{value: 1 ether}();
    }

    function test_RevertWhen_IssueOnOrAfterExpiry() public {
        vm.warp(expiry);
        vm.prank(issuer);
        vm.expectRevert(OptionToken.IssueClosed.selector);
        option.issue{value: 1 ether}();
    }

    function test_ExerciseOnExpiryDayWithUsdt() public {
        _issueAndDistribute(5 ether, alice, 2 ether);

        uint256 usdtCost = option.previewExerciseCost(2 ether);
        assertEq(usdtCost, 4000e6); // 2 ETH * 2000 USDT

        vm.warp(expiry);

        vm.startPrank(alice);
        usdt.approve(address(option), usdtCost);

        uint256 aliceEthBefore = alice.balance;
        uint256 issuerUsdtBefore = usdt.balanceOf(issuer);

        vm.expectEmit(true, true, true, true);
        emit Exercised(alice, 2 ether, usdtCost, 2 ether);

        option.exercise(2 ether);
        vm.stopPrank();

        assertEq(option.balanceOf(alice), 0);
        assertEq(option.totalSupply(), 3 ether); // issuer still holds 3
        assertEq(alice.balance, aliceEthBefore + 2 ether);
        assertEq(usdt.balanceOf(issuer), issuerUsdtBefore + usdtCost);
        assertEq(address(option).balance, 3 ether);
    }

    function test_RevertWhen_ExerciseBeforeExpiryDay() public {
        _issueAndDistribute(1 ether, alice, 1 ether);

        vm.prank(alice);
        usdt.approve(address(option), type(uint256).max);

        vm.prank(alice);
        vm.expectRevert(OptionToken.NotExerciseDay.selector);
        option.exercise(1 ether);
    }

    function test_RevertWhen_ExerciseAfterExpiryDay() public {
        _issueAndDistribute(1 ether, alice, 1 ether);

        vm.warp(expiry + 1 days);

        vm.startPrank(alice);
        usdt.approve(address(option), type(uint256).max);
        vm.expectRevert(OptionToken.NotExerciseDay.selector);
        option.exercise(1 ether);
        vm.stopPrank();
    }

    function test_ExerciseLateOnSameDayStillWorks() public {
        _issueAndDistribute(1 ether, alice, 1 ether);

        // 到期日最后一秒仍可行权
        vm.warp(expiry + 1 days - 1);

        uint256 cost = option.previewExerciseCost(1 ether);
        vm.startPrank(alice);
        usdt.approve(address(option), cost);
        option.exercise(1 ether);
        vm.stopPrank();

        assertEq(alice.balance, 1 ether);
        assertEq(option.totalSupply(), 0);
    }

    function test_ExpireAndRedeemBurnsIssuerOptionsAndRedeemsEth() public {
        _issueAndDistribute(10 ether, alice, 3 ether);
        // issuer 仍持有 7 ether 期权；alice 持有 3 且未行权

        vm.warp(expiry + 1 days);

        uint256 issuerEthBefore = issuer.balance;

        vm.expectEmit(true, true, true, true);
        emit ExpiredAndRedeemed(issuer, 7 ether, 10 ether);

        vm.prank(issuer);
        option.expireAndRedeem();

        assertTrue(option.redeemed());
        assertEq(option.balanceOf(issuer), 0);
        // alice 未行权的代币仍在账上，但已无法兑换标的（ETH 已全部赎回）
        assertEq(option.balanceOf(alice), 3 ether);
        assertEq(address(option).balance, 0);
        assertEq(issuer.balance, issuerEthBefore + 10 ether);
    }

    function test_RevertWhen_ExpireBeforeDeadline() public {
        _issueAndDistribute(1 ether, address(0), 0);

        vm.warp(expiry + 1 days - 1);
        vm.prank(issuer);
        vm.expectRevert(OptionToken.NotExpired.selector);
        option.expireAndRedeem();
    }

    function test_RevertWhen_ExpireTwice() public {
        _issueAndDistribute(1 ether, address(0), 0);

        vm.warp(expiry + 1 days);
        vm.prank(issuer);
        option.expireAndRedeem();

        vm.prank(issuer);
        vm.expectRevert(OptionToken.AlreadyRedeemed.selector);
        option.expireAndRedeem();
    }

    function test_RevertWhen_NonIssuerExpires() public {
        _issueAndDistribute(1 ether, address(0), 0);
        vm.warp(expiry + 1 days);

        vm.prank(alice);
        vm.expectRevert();
        option.expireAndRedeem();
    }

    function test_PartialExerciseThenExpireRedeemsRemainder() public {
        _issueAndDistribute(5 ether, alice, 5 ether);

        vm.warp(expiry);
        uint256 cost = option.previewExerciseCost(2 ether);

        vm.startPrank(alice);
        usdt.approve(address(option), cost);
        option.exercise(2 ether);
        vm.stopPrank();

        assertEq(address(option).balance, 3 ether);

        vm.warp(expiry + 1 days);
        uint256 issuerEthBefore = issuer.balance;

        vm.prank(issuer);
        option.expireAndRedeem();

        assertEq(address(option).balance, 0);
        assertEq(issuer.balance, issuerEthBefore + 3 ether);
        // alice 剩余 3 份期权已失效
        assertEq(option.balanceOf(alice), 3 ether);
    }

    function testFuzz_IssueAndExerciseRoundtrip(uint256 ethIn) public {
        ethIn = bound(ethIn, 1e15, 50 ether); // 至少能产生非零 USDT 成本

        vm.prank(issuer);
        option.issue{value: ethIn}();

        vm.prank(issuer);
        option.transfer(alice, ethIn);

        uint256 cost = option.previewExerciseCost(ethIn);
        assertGt(cost, 0);

        usdt.mint(alice, cost);

        vm.warp(expiry);
        vm.startPrank(alice);
        usdt.approve(address(option), cost);
        uint256 ethBefore = alice.balance;
        option.exercise(ethIn);
        vm.stopPrank();

        assertEq(alice.balance, ethBefore + ethIn);
        assertEq(option.totalSupply(), 0);
        assertEq(address(option).balance, 0);
    }
}
