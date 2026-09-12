// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {MyTokenERC2612Permit} from "../src/MyTokenERC2612Permit.sol";
import {TokenBankERC2612} from "../src/TokenBankERC2612.sol";

contract TokenBankERC2612Test is Test {
    MyTokenERC2612Permit public token;
    TokenBankERC2612 public bank;

    address public deployer = makeAddr("deployer");
    uint256 public alicePk = 0xA11CE;
    address public alice = vm.addr(alicePk);
    address public bob = makeAddr("bob");

    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    function setUp() public {
        vm.prank(deployer);
        token = new MyTokenERC2612Permit();
        vm.prank(deployer);
        bank = new TokenBankERC2612(token);
    }

    function _giveTokens(address to, uint256 amount) internal {
        vm.prank(deployer);
        token.transfer(to, amount);
    }

    function _signPermit(address owner, uint256 ownerPk, address spender, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, token.nonces(owner), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(ownerPk, digest);
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

    function test_PermitDeposit_Success() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 days;
        _giveTokens(alice, amount);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, address(bank), amount, deadline);

        vm.expectEmit(true, false, false, true, address(bank));
        emit Deposit(alice, amount);

        // msg.sender 即 owner:一笔 permitDeposit 完成授权+存款,无需事先 approve
        vm.prank(alice);
        bank.permitDeposit(amount, deadline, v, r, s);

        assertEq(bank.balances(alice), amount);
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(alice, address(bank)), 0);
        assertEq(token.nonces(alice), 1);
    }

    function test_PermitDeposit_ThenWithdraw() public {
        uint256 amount = 100e18;
        uint256 withdrawAmount = 40e18;
        uint256 deadline = block.timestamp + 1 days;
        _giveTokens(alice, amount);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, address(bank), amount, deadline);

        vm.prank(alice);
        bank.permitDeposit(amount, deadline, v, r, s);

        vm.expectEmit(true, false, false, true, address(bank));
        emit Withdraw(alice, withdrawAmount);

        vm.prank(alice);
        bank.withdraw(withdrawAmount);

        assertEq(bank.balances(alice), amount - withdrawAmount);
        assertEq(token.balanceOf(alice), withdrawAmount);
        assertEq(token.balanceOf(address(bank)), amount - withdrawAmount);
    }

    function test_PermitDeposit_ToleratesFrontrun() public {
        uint256 amount = 80e18;
        uint256 deadline = block.timestamp + 1 days;
        _giveTokens(alice, amount);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, address(bank), amount, deadline);

        // 抢跑:先单独调用 permit 消耗 nonce
        token.permit(alice, address(bank), amount, deadline, v, r, s);
        assertEq(token.allowance(alice, address(bank)), amount);
        assertEq(token.nonces(alice), 1);

        // permitDeposit 内 try/catch 吞掉重复 permit,仍能 transferFrom 入账
        vm.prank(alice);
        bank.permitDeposit(amount, deadline, v, r, s);

        assertEq(bank.balances(alice), amount);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(token.allowance(alice, address(bank)), 0);
    }

    function test_RevertWhen_PermitDeposit_ZeroAmount() public {
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, address(bank), 0, deadline);

        vm.prank(alice);
        vm.expectRevert("Zero deposit");
        bank.permitDeposit(0, deadline, v, r, s);
    }

    function test_RevertWhen_PermitDeposit_ExpiredAndNoAllowance() public {
        uint256 amount = 10e18;
        uint256 deadline = block.timestamp + 1 hours;
        _giveTokens(alice, amount);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, address(bank), amount, deadline);

        vm.warp(deadline + 1);
        // permit 失败且无既有 allowance,transferFrom 应回退
        vm.prank(alice);
        vm.expectRevert();
        bank.permitDeposit(amount, deadline, v, r, s);

        assertEq(bank.balances(alice), 0);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(bank)), 0);
        assertEq(token.allowance(alice, address(bank)), 0);
    }

    function test_RevertWhen_PermitDeposit_WrongSigner() public {
        uint256 amount = 10e18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 bobPk = 0xB0B;
        _giveTokens(alice, amount);

        // 签名与 msg.sender(alice) 不匹配
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, bobPk, address(bank), amount, deadline);

        vm.prank(alice);
        vm.expectRevert();
        bank.permitDeposit(amount, deadline, v, r, s);
    }

    function test_MixedDepositPaths_Accumulate() public {
        _giveTokens(alice, 200e18);
        uint256 deadline = block.timestamp + 1 days;

        vm.startPrank(alice);
        token.approve(address(bank), 100e18);
        bank.deposit(100e18);
        vm.stopPrank();

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, address(bank), 100e18, deadline);
        vm.prank(alice);
        bank.permitDeposit(100e18, deadline, v, r, s);

        assertEq(bank.balances(alice), 200e18);
        assertEq(token.balanceOf(address(bank)), 200e18);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(alice, address(bank)), 0);
    }

    function testFuzz_PermitDeposit_WithdrawRoundtrip(uint96 amount, uint96 withdrawAmount) public {
        amount = uint96(bound(amount, 1, 1_000_000e18));
        withdrawAmount = uint96(bound(withdrawAmount, 1, amount));
        uint256 deadline = block.timestamp + 1 days;

        _giveTokens(alice, amount);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, address(bank), amount, deadline);
        vm.prank(alice);
        bank.permitDeposit(amount, deadline, v, r, s);

        vm.prank(alice);
        bank.withdraw(withdrawAmount);

        assertEq(bank.balances(alice), amount - withdrawAmount);
        assertEq(token.balanceOf(alice), withdrawAmount);
        assertEq(token.balanceOf(address(bank)), amount - withdrawAmount);
    }
}
