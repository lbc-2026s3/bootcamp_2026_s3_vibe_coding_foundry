// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";
import {TokenBankV2} from "../src/TokenBankV2.sol";

contract TokenBankV2Test is Test {
    MyTokenV1 public token;
    TokenBankV2 public bank;

    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        vm.prank(deployer);
        token = new MyTokenV1();
        vm.prank(deployer);
        bank = new TokenBankV2(token);
    }

    /// @dev deployer 向 to 转账 amount 个 token
    function _giveTokens(address to, uint256 amount) internal {
        vm.prank(deployer);
        token.transfer(to, amount);
    }

    function test_Deposit_RecordsBalance() public {
        _giveTokens(alice, 100e18);
        vm.prank(alice);
        token.approve(address(bank), 100e18);

        vm.prank(alice);
        bank.deposit(100e18);

        assertEq(bank.balances(alice), 100e18);
        assertEq(token.balanceOf(address(bank)), 100e18);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_Deposit_RevertsOnZeroAmount() public {
        vm.expectRevert("Zero deposit");
        bank.deposit(0);
    }

    function test_Deposit_RevertsWithoutApproval() public {
        _giveTokens(alice, 100e18);
        // 未 approve:transferFrom 应回退
        vm.prank(alice);
        vm.expectRevert();
        bank.deposit(100e18);
    }

    function test_Deposit_MultipleUsers_RecordsIndependently() public {
        _giveTokens(alice, 100e18);
        _giveTokens(bob, 200e18);
        vm.prank(alice);
        token.approve(address(bank), 100e18);
        vm.prank(bob);
        token.approve(address(bank), 200e18);

        vm.prank(alice);
        bank.deposit(100e18);
        vm.prank(bob);
        bank.deposit(200e18);

        assertEq(bank.balances(alice), 100e18);
        assertEq(bank.balances(bob), 200e18);
        assertEq(token.balanceOf(address(bank)), 300e18);
    }

    function test_Deposit_TopUp_Accumulates() public {
        _giveTokens(alice, 150e18);
        vm.prank(alice);
        token.approve(address(bank), 150e18);

        vm.prank(alice);
        bank.deposit(100e18);
        vm.prank(alice);
        bank.deposit(50e18);

        assertEq(bank.balances(alice), 150e18);
        assertEq(token.balanceOf(address(bank)), 150e18);
    }

    function test_Withdraw_Partial_ReturnsTokensToUser() public {
        _giveTokens(alice, 100e18);
        vm.prank(alice);
        token.approve(address(bank), 100e18);
        vm.prank(alice);
        bank.deposit(100e18);

        vm.prank(alice);
        bank.withdraw(40e18);

        assertEq(bank.balances(alice), 60e18);
        assertEq(token.balanceOf(alice), 40e18);
        assertEq(token.balanceOf(address(bank)), 60e18);
    }

    function test_Withdraw_All_EmptiesRecordedBalance() public {
        _giveTokens(alice, 100e18);
        vm.prank(alice);
        token.approve(address(bank), 100e18);
        vm.prank(alice);
        bank.deposit(100e18);

        vm.prank(alice);
        bank.withdraw(100e18);

        assertEq(bank.balances(alice), 0);
        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.balanceOf(address(bank)), 0);
    }

    function test_Withdraw_RevertsOnZeroAmount() public {
        vm.expectRevert("Zero withdraw");
        bank.withdraw(0);
    }

    function test_Withdraw_RevertsWhenExceedingBalance() public {
        _giveTokens(alice, 100e18);
        vm.prank(alice);
        token.approve(address(bank), 100e18);
        vm.prank(alice);
        bank.deposit(100e18);

        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        bank.withdraw(101e18);
    }

    function test_Withdraw_RevertsWhenNothingDeposited() public {
        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        bank.withdraw(1);
    }

    function test_Withdraw_CannotTouchOthersBalance() public {
        _giveTokens(alice, 100e18);
        vm.prank(alice);
        token.approve(address(bank), 100e18);
        vm.prank(alice);
        bank.deposit(100e18);

        // bob 从未存入,无法提取任何 token
        vm.prank(bob);
        vm.expectRevert("Insufficient balance");
        bank.withdraw(1);

        // alice 的存款记录与 bank 资金均不受影响
        assertEq(bank.balances(alice), 100e18);
        assertEq(token.balanceOf(address(bank)), 100e18);
    }

    function test_Withdraw_NoAdmin_UsersWithdrawOwnFunds() public {
        // 无管理员:任何用户存入后即可自行提取,无需任何特权地址
        _giveTokens(alice, 100e18);
        _giveTokens(bob, 200e18);
        vm.prank(alice);
        token.approve(address(bank), 100e18);
        vm.prank(bob);
        token.approve(address(bank), 200e18);
        vm.prank(alice);
        bank.deposit(100e18);
        vm.prank(bob);
        bank.deposit(200e18);

        vm.prank(alice);
        bank.withdraw(100e18);
        vm.prank(bob);
        bank.withdraw(200e18);

        assertEq(bank.balances(alice), 0);
        assertEq(bank.balances(bob), 0);
        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.balanceOf(bob), 200e18);
        assertEq(token.balanceOf(address(bank)), 0);
    }

    /**
     * @dev 模糊测试:验证 deposit 后 withdraw 任意不超过余额的金额,账目始终一致
     * @param amount 模糊输入金额,uint96 类型
     * @param withdrawAmount 模糊输入提取金额,uint96 类型
     */
    function testFuzz_DepositWithdraw_KeepsBooks(uint96 amount, uint96 withdrawAmount) public {
        // 将 amount 边界约束在 [1, 100 万](初始供应上限),排除 0 值
        amount = uint96(bound(amount, 1, 1_000_000e18));
        // 提取金额约束在 [1, amount],覆盖部分与全额提取(0 提取回退由专门测试覆盖)
        withdrawAmount = uint96(bound(withdrawAmount, 1, amount));

        _giveTokens(alice, amount);
        vm.prank(alice);
        token.approve(address(bank), amount);
        vm.prank(alice);
        bank.deposit(amount);

        vm.prank(alice);
        bank.withdraw(withdrawAmount);

        assertEq(bank.balances(alice), amount - withdrawAmount);
        assertEq(token.balanceOf(alice), withdrawAmount);
        assertEq(token.balanceOf(address(bank)), amount - withdrawAmount);
    }
}
