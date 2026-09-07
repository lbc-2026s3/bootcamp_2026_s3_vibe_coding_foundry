// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC1363} from "openzeppelin-contracts/contracts/interfaces/IERC1363.sol";

import {MyTokenERC1363} from "../src/MyTokenERC1363.sol";
import {TokenBankERC1363} from "../src/TokenBankERC1363.sol";

contract TokenBankERC1363Test is Test {
    MyTokenERC1363 public token;
    TokenBankERC1363 public bank;

    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        vm.prank(deployer);
        token = new MyTokenERC1363();
        vm.prank(deployer);
        bank = new TokenBankERC1363(token);
    }

    function _giveTokens(address to, uint256 amount) internal {
        vm.prank(deployer);
        token.transfer(to, amount);
    }

    function test_Deposit_ViaApproveAndDeposit() public {
        _giveTokens(alice, 100e18);

        vm.startPrank(alice);
        token.approve(address(bank), 100e18);
        bank.deposit(100e18);
        vm.stopPrank();

        assertEq(bank.balances(alice), 100e18);
        assertEq(token.balanceOf(address(bank)), 100e18);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_Deposit_ViaTransferAndCall() public {
        _giveTokens(alice, 100e18);

        vm.prank(alice);
        token.transferAndCall(address(bank), 100e18);

        assertEq(bank.balances(alice), 100e18);
        assertEq(token.balanceOf(address(bank)), 100e18);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_Deposit_ViaTransferAndCallWithData() public {
        _giveTokens(alice, 50e18);

        vm.prank(alice);
        // 此场景 tokenbank 中没有使用这里传入的 data：bytes("deposit")
        token.transferAndCall(address(bank), 50e18, bytes("deposit"));

        assertEq(bank.balances(alice), 50e18);
        assertEq(token.balanceOf(address(bank)), 50e18);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_Deposit_ViaApproveAndCall() public {
        _giveTokens(alice, 80e18);

        vm.prank(alice);
        token.approveAndCall(address(bank), 80e18);

        assertEq(bank.balances(alice), 80e18);
        assertEq(token.balanceOf(address(bank)), 80e18);
        assertEq(token.balanceOf(alice), 0);
        // approveAndCall 后 allowance 已被 transferFrom 花完
        // TokenBank onApprovalReceived 回调中自动调用 transferFrom 完成转账
        assertEq(token.allowance(alice, address(bank)), 0);
    }

    function test_Deposit_ViaTransferFromAndCall() public {
        _giveTokens(alice, 60e18);

        vm.prank(alice);
        token.approve(bob, 60e18);

        vm.prank(bob);
        token.transferFromAndCall(alice, address(bank), 60e18);

        // 入账记在 token 来源地址 alice,而非 operator bob
        assertEq(bank.balances(alice), 60e18);
        assertEq(bank.balances(bob), 0);
        assertEq(token.balanceOf(address(bank)), 60e18);
        assertEq(token.allowance(alice, bob), 0);
    }

    function test_Deposit_DoesNotDoubleCount_ApprovePath() public {
        _giveTokens(alice, 40e18);

        vm.startPrank(alice);
        token.approve(address(bank), 40e18);
        bank.deposit(40e18);
        vm.stopPrank();

        // 普通 transferFrom 不触发 onTransferReceived,余额必须恰好为 amount
        assertEq(bank.balances(alice), 40e18);
        assertEq(token.balanceOf(address(bank)), 40e18);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_Withdraw_AfterTransferAndCall() public {
        _giveTokens(alice, 100e18);

        vm.prank(alice);
        token.transferAndCall(address(bank), 100e18);

        vm.prank(alice);
        bank.withdraw(40e18);

        assertEq(bank.balances(alice), 60e18);
        assertEq(token.balanceOf(alice), 40e18);
        assertEq(token.balanceOf(address(bank)), 60e18);
    }

    function test_RevertWhen_OnTransferReceived_WrongToken() public {
        MyTokenERC1363 other = new MyTokenERC1363();
        other.transfer(alice, 10e18);

        vm.prank(alice);
        vm.expectRevert("Invalid token");
        other.transferAndCall(address(bank), 10e18);
    }

    function test_RevertWhen_TransferAndCall_ZeroAmount() public {
        _giveTokens(alice, 1e18);

        vm.prank(alice);
        vm.expectRevert("Zero deposit");
        token.transferAndCall(address(bank), 0);
    }

    function test_RevertWhen_ApproveAndCall_ZeroAmount() public {
        _giveTokens(alice, 1e18);

        vm.prank(alice);
        vm.expectRevert("Zero deposit");
        token.approveAndCall(address(bank), 0);
    }

    function test_RevertWhen_WithdrawExceedsBalance() public {
        _giveTokens(alice, 10e18);
        vm.prank(alice);
        token.transferAndCall(address(bank), 10e18);

        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        bank.withdraw(11e18);
    }

    function test_MixedDepositPaths_Accumulate() public {
        _giveTokens(alice, 300e18);

        vm.startPrank(alice);
        token.approve(address(bank), 100e18);
        bank.deposit(100e18);
        token.transferAndCall(address(bank), 100e18);
        token.approveAndCall(address(bank), 100e18);
        vm.stopPrank();

        assertEq(bank.balances(alice), 300e18);
        assertEq(token.balanceOf(address(bank)), 300e18);
        assertEq(token.balanceOf(alice), 0);
    }

    /**
     * @dev 模糊测试:transferAndCall 存入后任意提取,账目始终一致
     * Foundry 会随机传入 amount / withdrawAmount 跑很多次(默认 256 次)
     * @param amount 随机存入金额
     * @param withdrawAmount 随机提取金额(不超过存入)
     */
    function testFuzz_TransferAndCall_WithdrawRoundtrip(uint96 amount, uint96 withdrawAmount) public {
        // 约束到合法区间:存入 [1, 100万],提取 [1, amount],排除 0 与超余额
        amount = uint96(bound(amount, 1, 1_000_000e18));
        withdrawAmount = uint96(bound(withdrawAmount, 1, amount));

        _giveTokens(alice, amount);

        // 路径:token.transferAndCall -> bank.onTransferReceived 入账
        vm.prank(alice);
        token.transferAndCall(address(bank), amount);

        vm.prank(alice);
        bank.withdraw(withdrawAmount);

        // 银行记账 + 链上余额两边都要对得上
        assertEq(bank.balances(alice), amount - withdrawAmount);
        assertEq(token.balanceOf(alice), withdrawAmount);
        assertEq(token.balanceOf(address(bank)), amount - withdrawAmount);
    }

    /**
     * @dev 模糊测试:approveAndCall 全额存入再全额取出(往返),最终应回到初始状态
     * @param amount 随机存入并全部提取的金额
     */
    function testFuzz_ApproveAndCall_WithdrawRoundtrip(uint96 amount) public {
        amount = uint96(bound(amount, 1, 1_000_000e18));
        _giveTokens(alice, amount);

        // 路径:approveAndCall -> bank.onApprovalReceived 内 transferFrom 拉款入账
        vm.prank(alice);
        IERC1363(address(token)).approveAndCall(address(bank), amount);

        vm.prank(alice);
        bank.withdraw(amount);

        // 全额往返后:银行记账为 0,token 全部回到 alice
        assertEq(bank.balances(alice), 0);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(bank)), 0);
    }
}

