// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";
import {TokenBankV1} from "../src/TokenBankV1.sol";

contract TokenBankV1Test is Test {
    MyTokenV1 public token;
    TokenBankV1 public bank;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        // 部署者即管理员:以 admin 身份部署 token 与 bank
        vm.prank(admin);
        token = new MyTokenV1();
        vm.prank(admin);
        bank = new TokenBankV1(token);
    }

    /// @dev 管理员向 to 转账 amount 个 token
    function _giveTokens(address to, uint256 amount) internal {
        vm.prank(admin);
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

    function test_Withdraw_RevertsIfNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert("Only admin");
        bank.withdraw();
    }

    function test_Withdraw_RevertsWhenNothingToWithdraw() public {
        vm.prank(admin);
        vm.expectRevert("Nothing to withdraw");
        bank.withdraw();
    }

    function test_Withdraw_AdminGetsAllTokens() public {
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

        uint256 adminBalanceBefore = token.balanceOf(admin);
        vm.prank(admin);
        bank.withdraw();

        assertEq(token.balanceOf(address(bank)), 0);
        assertEq(token.balanceOf(admin), adminBalanceBefore + 300e18);
        // 存款记录保留
        assertEq(bank.balances(alice), 100e18);
        assertEq(bank.balances(bob), 200e18);
    }

    function test_TransferAdmin_UpdatesAdmin() public {
        vm.expectEmit(true, true, false, false);
        emit TokenBankV1.AdminTransferred(admin, alice);

        vm.prank(admin);
        bank.transferAdmin(alice);

        assertEq(bank.admin(), alice);
    }

    function test_TransferAdmin_RevertsIfNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert("Only admin");
        bank.transferAdmin(bob);
    }

    function test_TransferAdmin_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Zero address");
        bank.transferAdmin(address(0));
    }

    function test_TransferAdmin_NewAdminCanWithdraw() public {
        _giveTokens(alice, 100e18);
        vm.prank(alice);
        token.approve(address(bank), 100e18);
        vm.prank(alice);
        bank.deposit(100e18);

        vm.prank(admin);
        bank.transferAdmin(bob);

        // 旧 admin 不能再提取
        vm.prank(admin);
        vm.expectRevert("Only admin");
        bank.withdraw();

        // 新 admin 可以提取
        uint256 bobBalanceBefore = token.balanceOf(bob);
        vm.prank(bob);
        bank.withdraw();

        assertEq(token.balanceOf(address(bank)), 0);
        assertEq(token.balanceOf(bob), bobBalanceBefore + 100e18);
    }

    /**
     * @dev 模糊测试：验证 deposit 存款后余额记录正确性
     * @param amount 模糊输入存款金额，uint96 类型
     */
    function testFuzz_Deposit_RecordsBalance(uint96 amount) public {
        // 将 amount 边界约束在 [1, 100 万]（初始供应上限），排除 0 值
        amount = uint96(bound(amount, 1, 1_000_000e18));

        // 管理员转给 alice amount 个 token
        _giveTokens(alice, amount);

        // 模拟以 alice 身份 approve 并存入
        vm.prank(alice);
        token.approve(address(bank), amount);
        vm.prank(alice);
        bank.deposit(amount);

        // 断言：合约内 alice 的用户余额等于存入金额
        assertEq(bank.balances(alice), amount);
        // 断言：bank 合约自身 token 余额等于存入金额
        assertEq(token.balanceOf(address(bank)), amount);
    }
}
