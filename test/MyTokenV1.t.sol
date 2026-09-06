// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";

contract MyTokenV1Test is Test {
    MyTokenV1 public token;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        // 部署者即初始持有者:以 admin 身份部署
        vm.prank(admin);
        token = new MyTokenV1();
    }

    function test_Token_Metadata() public view {
        assertEq(token.name(), "MyToken");
        assertEq(token.symbol(), "MT");
        assertEq(token.decimals(), 18);
    }

    function test_Token_InitialSupplyMintedToDeployer() public view {
        assertEq(token.totalSupply(), token.INITIAL_SUPPLY());
        assertEq(token.balanceOf(admin), token.INITIAL_SUPPLY());
    }

    // ===== transfer 测试 =====
    function test_Transfer_Success() public {
        uint256 transferAmount = 100 ether;

        // admin 转账给 alice
        vm.prank(admin);
        token.transfer(alice, transferAmount);

        assertEq(token.balanceOf(admin), token.INITIAL_SUPPLY() - transferAmount);
        assertEq(token.balanceOf(alice), transferAmount);
    }

    function test_Transfer_Fail_InsufficientBalance() public {
        uint256 tooMuch = token.INITIAL_SUPPLY() + 1 ether;

        vm.prank(admin);
        vm.expectRevert();
        token.transfer(alice, tooMuch);
    }

    function test_Transfer_ToZeroAddress() public {
        uint256 amount = 50 ether;
        vm.prank(admin);
        vm.expectRevert();
        token.transfer(address(0), amount);
    }

    // ===== approve + transferFrom 测试 =====
    function test_Approve_Success() public {
        uint256 approveAmount = 200 ether;

        // admin 授权 bob
        vm.prank(admin);
        token.approve(bob, approveAmount);

        assertEq(token.allowance(admin, bob), approveAmount);
    }

    function test_TransferFrom_Success() public {
        uint256 approveAmount = 300 ether;
        uint256 transferAmount = 200 ether;

        // admin 授权 bob
        vm.prank(admin);
        token.approve(bob, approveAmount);

        // bob 使用 transferFrom 把 admin 的钱转给 alice
        vm.prank(bob);
        token.transferFrom(admin, alice, transferAmount);

        assertEq(token.balanceOf(admin), token.INITIAL_SUPPLY() - transferAmount);
        assertEq(token.balanceOf(alice), transferAmount);
        // allowance 扣减
        assertEq(token.allowance(admin, bob), approveAmount - transferAmount);
    }

    function test_TransferFrom_Fail_InsufficientAllowance() public {
        uint256 approveAmount = 100 ether;
        uint256 transferAmount = 200 ether;

        vm.prank(admin);
        token.approve(bob, approveAmount);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(admin, alice, transferAmount);
    }

    function test_TransferFrom_Fail_InsufficientSenderBalance() public {
        uint256 approveAmount = 1000 ether;
        uint256 transferAmount = 500 ether;
        // 提前读取余额,避免 vm.prank 被 INITIAL_SUPPLY() 的 getter 调用消耗
        uint256 initialSupply = token.INITIAL_SUPPLY();

        // admin 先把钱全部转走，余额为0
        vm.prank(admin);
        token.transfer(alice, initialSupply);

        vm.prank(admin);
        token.approve(bob, approveAmount);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(admin, bob, transferAmount);
    }

    function test_TransferFrom_ToZeroAddress() public {
        uint256 approveAmount = 100 ether;
        vm.prank(admin);
        token.approve(bob, approveAmount);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(admin, address(0), 50 ether);
    }
}
