// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ETHBank} from "../src/ETHBank.sol";

contract ETHBankTest is Test {
    ETHBank public bank;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public dave = makeAddr("dave");

    function setUp() public {
        // 部署者即管理员:以 admin 身份部署
        vm.prank(admin);
        bank = new ETHBank();
    }

    function test_Deposit_RecordsBalance() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        assertEq(bank.balances(alice), 1 ether);
        assertEq(bank.depositorCount(), 1);
    }

    function test_Receive_RecordsBalance() public {
        // MetaMask 直接转账 ETH 走 receive()
        vm.deal(alice, 0.5 ether);
        vm.prank(alice);
        (bool ok,) = address(bank).call{value: 0.5 ether}("");

        assertTrue(ok);
        assertEq(bank.balances(alice), 0.5 ether);
        assertEq(bank.depositorCount(), 1);
    }

    function test_Deposit_RevertsOnZeroAmount() public {
        vm.expectRevert("Zero deposit");
        bank.deposit{value: 0}();
    }

    function test_Deposit_TopUp_AccumulatesAndResorts() public {
        vm.deal(alice, 3 ether);
        vm.deal(bob, 2 ether);
        vm.deal(carol, 1 ether);

        vm.prank(alice);
        bank.deposit{value: 3 ether}();
        vm.prank(bob);
        bank.deposit{value: 2 ether}();
        vm.prank(carol);
        bank.deposit{value: 1 ether}();
        assertEq(bank.depositorCount(), 3);

        (address[3] memory top3, uint256[3] memory amounts) = bank.getTop3();
        assertEq(top3[0], alice);
        assertEq(top3[1], bob);
        assertEq(top3[2], carol);
        assertEq(amounts[0], 3 ether);
        assertEq(amounts[1], 2 ether);
        assertEq(amounts[2], 1 ether);

        // carol 加仓 5 ETH,累计 6 ETH,应跃居第一
        vm.deal(carol, 5 ether);
        vm.prank(carol);
        bank.deposit{value: 5 ether}();

        assertEq(bank.balances(carol), 6 ether);
        (top3, amounts) = bank.getTop3();
        assertEq(top3[0], carol);
        assertEq(top3[1], alice);
        assertEq(top3[2], bob);
        assertEq(amounts[0], 6 ether);
        assertEq(amounts[1], 3 ether);
        assertEq(amounts[2], 2 ether);

        assertEq(bank.depositorCount(), 3);
    }

    function test_GetTop3_OrderedByBalance() public {
        vm.deal(alice, 4 ether);
        vm.deal(bob, 1 ether);
        vm.deal(carol, 3 ether);
        vm.deal(dave, 2 ether);

        vm.prank(bob);
        bank.deposit{value: 1 ether}();
        vm.prank(dave);
        bank.deposit{value: 2 ether}();
        vm.prank(carol);
        bank.deposit{value: 3 ether}();
        vm.prank(alice);
        bank.deposit{value: 4 ether}();

        (address[3] memory top3, uint256[3] memory amounts) = bank.getTop3();
        assertEq(top3[0], alice);
        assertEq(top3[1], carol);
        assertEq(top3[2], dave);
        assertEq(amounts[0], 4 ether);
        assertEq(amounts[1], 3 ether);
        assertEq(amounts[2], 2 ether);

        assertEq(bank.depositorCount(), 4);
    }

    function test_GetTop3_WithFewerThanThreeDepositors() public {
        vm.deal(alice, 2 ether);
        vm.deal(bob, 1 ether);

        vm.prank(alice);
        bank.deposit{value: 2 ether}();
        vm.prank(bob);
        bank.deposit{value: 1 ether}();

        (address[3] memory top3, uint256[3] memory amounts) = bank.getTop3();
        assertEq(top3[0], alice);
        assertEq(top3[1], bob);
        assertEq(top3[2], address(0));
        assertEq(amounts[2], 0);

        assertEq(bank.depositorCount(), 2);
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

    function test_Withdraw_AdminGetsAllEth() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        uint256 adminBalanceBefore = admin.balance;
        vm.prank(admin);
        bank.withdraw();

        assertEq(address(bank).balance, 0);
        assertEq(admin.balance, adminBalanceBefore + 1 ether);
        // 存款记录与链表状态保留
        assertEq(bank.balances(alice), 1 ether);
    }

    /**
     * @dev 模糊测试：验证deposit存款后余额记录正确性
     * @param amount 模糊输入存款金额，uint96类型
     */
    function testFuzz_Deposit_RecordsBalance(uint96 amount) public {
        // 将amount边界约束在 [1, uint96最大值]，排除0值
        amount = uint96(bound(amount, 1, type(uint96).max));
        
        // 给alice账户设置amount数量ETH余额
        vm.deal(alice, amount);
        
        // 模拟以alice身份发起调用
        vm.prank(alice);
        // alice向bank合约存入amount以太币
        bank.deposit{value: amount}();

        // 断言：合约内alice的用户余额等于存入金额
        assertEq(bank.balances(alice), amount);
        // 断言：bank合约自身ETH余额等于存入金额
        assertEq(address(bank).balance, amount);
        assertEq(bank.depositorCount(), 1);
    }
}
