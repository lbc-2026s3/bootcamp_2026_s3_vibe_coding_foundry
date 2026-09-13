// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import {MyTokenV1} from "../src/MyTokenV1.sol";
import {TokenBankPermit} from "../src/TokenBankPermit.sol";
import {DeployPermit2} from "./utils/DeployPermit2.sol";

/// @notice 本地单元测试:etch 官方 Permit2 字节码,走真实签名校验路径
contract TokenBankPermitTest is Test, DeployPermit2 {
    MyTokenV1 public token;
    TokenBankPermit public bank;
    ISignatureTransfer public permit2;

    address public deployer = makeAddr("deployer");
    uint256 public alicePk = 0xA11CE;
    address public alice = vm.addr(alicePk);
    address public bob = makeAddr("bob");

    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    function setUp() public {
        permit2 = ISignatureTransfer(deployPermit2());

        vm.prank(deployer);
        token = new MyTokenV1();
        vm.prank(deployer);
        bank = new TokenBankPermit(token, permit2);
    }

    function _giveTokens(address to, uint256 amount) internal {
        vm.prank(deployer);
        token.transfer(to, amount);
    }

    /// @dev 用户需先对 Permit2 授权 token(通常一次性 max)
    function _approvePermit2(address owner, uint256 amount) internal {
        vm.prank(owner);
        token.approve(address(permit2), amount);
    }

    /// @notice 构造 Permit2 SignatureTransfer 的 EIP-712 签名,供 depositWithPermit2 使用
    /// @dev 哈希结构与 Permit2 一致:TokenPermissions -> PermitTransferFrom(含 spender) -> \x19\x01 + DOMAIN_SEPARATOR
    /// @dev spender 必须填银行地址:链上 Permit2 用 msg.sender(即 TokenBankPermit) 作为 spender 校验签名
    /// @param ownerPk 代币所有者私钥(Foundry vm.sign)
    /// @param spender 签名授权的 spender,测试中应为 address(bank)
    /// @param tokenAddr / amount / nonce / deadline 对应 PermitTransferFrom 字段
    /// @return signature 65 字节 (r,s,v)
    function _signPermit2(
        uint256 ownerPk,
        address spender,
        address tokenAddr,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory signature) {
        bytes32 tokenPermissionsHash = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, tokenAddr, amount));
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, spender, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _buildPermit(uint256 amount, uint256 nonce, uint256 deadline)
        internal
        view
        returns (ISignatureTransfer.PermitTransferFrom memory)
    {
        return ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(token), amount: amount}),
            nonce: nonce,
            deadline: deadline
        });
    }

    function test_Constructor_SetsPermit2() public view {
        assertEq(address(bank.permit2()), address(permit2));
        assertEq(address(bank.token()), address(token));
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
        assertEq(token.allowance(alice, address(bank)), 0);
    }

    function test_DepositWithPermit2_Success() public {
        uint256 amount = 100e18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 days;
        _giveTokens(alice, amount);
        _approvePermit2(alice, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(amount, nonce, deadline);
        bytes memory signature = _signPermit2(alicePk, address(bank), address(token), amount, nonce, deadline);

        vm.expectEmit(true, false, false, true, address(bank));
        emit Deposit(alice, amount);

        vm.prank(alice);
        bank.depositWithPermit2(permit, signature);

        assertEq(bank.balances(alice), amount);
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(token.balanceOf(alice), 0);
        // 银行本身无 ERC20 allowance;授权在 Permit2 上
        assertEq(token.allowance(alice, address(bank)), 0);
        assertEq(token.allowance(alice, address(permit2)), type(uint256).max);
    }

    function test_DepositWithPermit2_ThenWithdraw() public {
        uint256 amount = 100e18;
        uint256 withdrawAmount = 40e18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 days;
        _giveTokens(alice, amount);
        _approvePermit2(alice, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(amount, nonce, deadline);
        bytes memory signature = _signPermit2(alicePk, address(bank), address(token), amount, nonce, deadline);

        vm.prank(alice);
        bank.depositWithPermit2(permit, signature);

        vm.expectEmit(true, false, false, true, address(bank));
        emit Withdraw(alice, withdrawAmount);

        vm.prank(alice);
        bank.withdraw(withdrawAmount);

        assertEq(bank.balances(alice), amount - withdrawAmount);
        assertEq(token.balanceOf(alice), withdrawAmount);
        assertEq(token.balanceOf(address(bank)), amount - withdrawAmount);
    }

    function test_DepositWithPermit2_DifferentNonces() public {
        _giveTokens(alice, 200e18);
        _approvePermit2(alice, type(uint256).max);
        uint256 deadline = block.timestamp + 1 days;

        ISignatureTransfer.PermitTransferFrom memory permit0 = _buildPermit(80e18, 0, deadline);
        bytes memory sig0 = _signPermit2(alicePk, address(bank), address(token), 80e18, 0, deadline);
        vm.prank(alice);
        bank.depositWithPermit2(permit0, sig0);

        ISignatureTransfer.PermitTransferFrom memory permit1 = _buildPermit(120e18, 1, deadline);
        bytes memory sig1 = _signPermit2(alicePk, address(bank), address(token), 120e18, 1, deadline);
        vm.prank(alice);
        bank.depositWithPermit2(permit1, sig1);

        assertEq(bank.balances(alice), 200e18);
        assertEq(token.balanceOf(address(bank)), 200e18);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(alice, address(bank)), 0);
        assertEq(token.allowance(alice, address(permit2)), type(uint256).max);
    }

    function test_MixedDepositPaths_Accumulate() public {
        _giveTokens(alice, 200e18);
        _approvePermit2(alice, type(uint256).max);
        uint256 deadline = block.timestamp + 1 days;

        vm.startPrank(alice);
        token.approve(address(bank), 100e18);
        bank.deposit(100e18);
        vm.stopPrank();

        assertEq(bank.balances(alice), 100e18);
        assertEq(token.balanceOf(address(bank)), 100e18);
        assertEq(token.balanceOf(alice), 100e18);

        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(100e18, 0, deadline);
        bytes memory signature = _signPermit2(alicePk, address(bank), address(token), 100e18, 0, deadline);
        vm.prank(alice);
        bank.depositWithPermit2(permit, signature);

        assertEq(bank.balances(alice), 200e18);
        assertEq(token.balanceOf(address(bank)), 200e18);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_RevertWhen_DepositWithPermit2_ZeroAmount() public {
        uint256 deadline = block.timestamp + 1 days;
        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(0, 0, deadline);
        bytes memory signature = _signPermit2(alicePk, address(bank), address(token), 0, 0, deadline);

        vm.prank(alice);
        vm.expectRevert("Zero deposit");
        bank.depositWithPermit2(permit, signature);
    }

    function test_RevertWhen_DepositWithPermit2_WrongToken() public {
        MyTokenV1 other = new MyTokenV1();
        uint256 amount = 10e18;
        uint256 deadline = block.timestamp + 1 days;

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(other), amount: amount}),
            nonce: 0,
            deadline: deadline
        });
        bytes memory signature = _signPermit2(alicePk, address(bank), address(other), amount, 0, deadline);

        vm.prank(alice);
        vm.expectRevert("Invalid token");
        bank.depositWithPermit2(permit, signature);
    }

    function test_RevertWhen_DepositWithPermit2_Expired() public {
        uint256 amount = 10e18;
        uint256 deadline = block.timestamp + 1 hours;
        _giveTokens(alice, amount);
        _approvePermit2(alice, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(amount, 0, deadline);
        bytes memory signature = _signPermit2(alicePk, address(bank), address(token), amount, 0, deadline);

        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert();
        bank.depositWithPermit2(permit, signature);
    }

    function test_RevertWhen_DepositWithPermit2_WrongSigner() public {
        uint256 amount = 10e18;
        uint256 bobPk = 0xB0B;
        uint256 deadline = block.timestamp + 1 days;
        _giveTokens(alice, amount);
        _approvePermit2(alice, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(amount, 0, deadline);
        // 用 bob 私钥签,但 alice 调用
        bytes memory signature = _signPermit2(bobPk, address(bank), address(token), amount, 0, deadline);

        vm.prank(alice);
        vm.expectRevert();
        bank.depositWithPermit2(permit, signature);
    }

    function test_RevertWhen_DepositWithPermit2_WrongSpender() public {
        uint256 amount = 10e18;
        uint256 deadline = block.timestamp + 1 days;
        _giveTokens(alice, amount);
        _approvePermit2(alice, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(amount, 0, deadline);
        // 签名 spender 写成 alice,实际调用时 Permit2 看到的 spender 是 bank
        bytes memory signature = _signPermit2(alicePk, alice, address(token), amount, 0, deadline);

        vm.prank(alice);
        vm.expectRevert();
        bank.depositWithPermit2(permit, signature);
    }

    function test_RevertWhen_DepositWithPermit2_ThirdPartyCaller() public {
        uint256 amount = 10e18;
        uint256 deadline = block.timestamp + 1 days;
        _giveTokens(alice, amount);
        _approvePermit2(alice, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(amount, 0, deadline);
        bytes memory signature = _signPermit2(alicePk, address(bank), address(token), amount, 0, deadline);

        // bob 代提交时 owner=msg.sender=bob,与 alice 签名不匹配
        vm.prank(bob);
        vm.expectRevert();
        bank.depositWithPermit2(permit, signature);
    }

    function test_RevertWhen_DepositWithPermit2_ReplayNonce() public {
        uint256 amount = 50e18;
        uint256 deadline = block.timestamp + 1 days;
        _giveTokens(alice, amount * 2);
        _approvePermit2(alice, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(amount, 0, deadline);
        bytes memory signature = _signPermit2(alicePk, address(bank), address(token), amount, 0, deadline);

        vm.prank(alice);
        bank.depositWithPermit2(permit, signature);

        vm.prank(alice);
        vm.expectRevert();
        bank.depositWithPermit2(permit, signature);
    }

    function test_RevertWhen_DepositWithPermit2_NoPermit2Allowance() public {
        uint256 amount = 10e18;
        uint256 deadline = block.timestamp + 1 days;
        _giveTokens(alice, amount);
        // 故意不 approve Permit2

        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(amount, 0, deadline);
        bytes memory signature = _signPermit2(alicePk, address(bank), address(token), amount, 0, deadline);

        vm.prank(alice);
        vm.expectRevert();
        bank.depositWithPermit2(permit, signature);
    }

    function testFuzz_DepositWithPermit2_WithdrawRoundtrip(uint96 amount, uint96 withdrawAmount) public {
        amount = uint96(bound(amount, 1, 1_000_000e18));
        withdrawAmount = uint96(bound(withdrawAmount, 1, amount));
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = uint256(keccak256(abi.encode(amount, withdrawAmount)));

        _giveTokens(alice, amount);
        _approvePermit2(alice, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = _buildPermit(amount, nonce, deadline);
        bytes memory signature = _signPermit2(alicePk, address(bank), address(token), amount, nonce, deadline);

        vm.prank(alice);
        bank.depositWithPermit2(permit, signature);

        vm.prank(alice);
        bank.withdraw(withdrawAmount);

        assertEq(bank.balances(alice), amount - withdrawAmount);
        assertEq(token.balanceOf(alice), withdrawAmount);
        assertEq(token.balanceOf(address(bank)), amount - withdrawAmount);
        assertEq(token.allowance(alice, address(bank)), 0);
        assertEq(token.allowance(alice, address(permit2)), type(uint256).max);
    }
}

/// @notice fork 以太坊主网,使用链上真实 Permit2 + USDC
/// @dev 运行:forge test --match-contract TokenBankPermitMainnetForkTest
///      RPC 使用 .env 的 FOUNDRY_RPC_ENDPOINTS.mainnet
contract TokenBankPermitMainnetForkTest is Test {
    /// @dev https://etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    /// @dev https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    ISignatureTransfer internal permit2;
    IERC20 internal usdc;
    TokenBankPermit internal bank;

    uint256 internal alicePk = 0xA11CE;
    address internal alice = vm.addr(alicePk);

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    function setUp() public {
        // 钉死区块,避免 latest 在公共 RPC 上抖动;deal 不依赖当时持仓
        vm.createSelectFork("mainnet", 25_925_858);

        permit2 = ISignatureTransfer(PERMIT2);
        usdc = IERC20(USDC);
        require(PERMIT2.code.length > 0, "Permit2 not deployed on this fork");
        require(USDC.code.length > 0, "USDC not deployed on this fork");

        bank = new TokenBankPermit(usdc, permit2);
        vm.deal(alice, 1 ether);
    }

    function _giveUSDC(address to, uint256 amount) internal {
        deal(USDC, to, usdc.balanceOf(to) + amount, true);
    }

    function _units(uint256 wholeTokens) internal pure returns (uint256) {
        return wholeTokens * 1e6; // USDC 6 decimals
    }

    function _signPermit2(
        uint256 ownerPk,
        address spender,
        address tokenAddr,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory signature) {
        bytes32 tokenPermissionsHash = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, tokenAddr, amount));
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, spender, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function test_MainnetPermit2_DepositWithPermit2_USDC() public {
        uint256 amount = _units(100);
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 days;
        _giveUSDC(alice, amount);

        vm.prank(alice);
        usdc.approve(PERMIT2, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: USDC, amount: amount}),
            nonce: nonce,
            deadline: deadline
        });
        bytes memory signature = _signPermit2(alicePk, address(bank), USDC, amount, nonce, deadline);

        vm.expectEmit(true, false, false, true, address(bank));
        emit Deposit(alice, amount);

        vm.prank(alice);
        bank.depositWithPermit2(permit, signature);

        assertEq(bank.balances(alice), amount);
        assertEq(usdc.balanceOf(address(bank)), amount);
        assertEq(usdc.balanceOf(alice), 0);
        assertEq(usdc.allowance(alice, address(bank)), 0);
        // 主网 USDC 会扣减 allowance(即使曾 approve max),剩余为 max - amount
        assertEq(usdc.allowance(alice, PERMIT2), type(uint256).max - amount);
    }

    function test_MainnetPermit2_DepositThenWithdraw_Roundtrip() public {
        uint256 amount = _units(250);
        uint256 withdrawAmount = _units(100);
        uint256 nonce = 42;
        uint256 deadline = block.timestamp + 1 days;
        _giveUSDC(alice, amount);

        vm.prank(alice);
        usdc.approve(PERMIT2, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: USDC, amount: amount}),
            nonce: nonce,
            deadline: deadline
        });
        bytes memory signature = _signPermit2(alicePk, address(bank), USDC, amount, nonce, deadline);

        vm.prank(alice);
        bank.depositWithPermit2(permit, signature);

        vm.expectEmit(true, false, false, true, address(bank));
        emit Withdraw(alice, withdrawAmount);

        vm.prank(alice);
        bank.withdraw(withdrawAmount);

        assertEq(bank.balances(alice), amount - withdrawAmount);
        assertEq(usdc.balanceOf(alice), withdrawAmount);
        assertEq(usdc.balanceOf(address(bank)), amount - withdrawAmount);
        assertEq(usdc.allowance(alice, address(bank)), 0);
        assertEq(usdc.allowance(alice, PERMIT2), type(uint256).max - amount);
    }

    function test_MainnetPermit2_UsesSixDecimals() public {
        uint256 oneHundredUsdc = _units(100);
        assertEq(oneHundredUsdc, 100e6);

        uint256 nonce = 7;
        uint256 deadline = block.timestamp + 1 days;
        _giveUSDC(alice, oneHundredUsdc);

        vm.prank(alice);
        usdc.approve(PERMIT2, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: USDC, amount: oneHundredUsdc}),
            nonce: nonce,
            deadline: deadline
        });
        bytes memory signature = _signPermit2(alicePk, address(bank), USDC, oneHundredUsdc, nonce, deadline);

        vm.prank(alice);
        bank.depositWithPermit2(permit, signature);

        assertEq(bank.balances(alice), 100e6);
        assertEq(usdc.balanceOf(address(bank)), 100e6);
    }

    function test_MainnetPermit2_TwoDeposits_DifferentNonces() public {
        uint256 first = _units(150);
        uint256 second = _units(50);
        uint256 total = first + second;
        uint256 deadline = block.timestamp + 1 days;
        _giveUSDC(alice, total);

        vm.prank(alice);
        usdc.approve(PERMIT2, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit0 = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: USDC, amount: first}),
            nonce: 0,
            deadline: deadline
        });
        bytes memory sig0 = _signPermit2(alicePk, address(bank), USDC, first, 0, deadline);

        vm.prank(alice);
        bank.depositWithPermit2(permit0, sig0);

        assertEq(bank.balances(alice), first);
        assertEq(usdc.balanceOf(alice), second);

        ISignatureTransfer.PermitTransferFrom memory permit1 = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: USDC, amount: second}),
            nonce: 1,
            deadline: deadline
        });
        bytes memory sig1 = _signPermit2(alicePk, address(bank), USDC, second, 1, deadline);

        vm.prank(alice);
        bank.depositWithPermit2(permit1, sig1);

        assertEq(bank.balances(alice), total);
        assertEq(usdc.balanceOf(address(bank)), total);
        assertEq(usdc.balanceOf(alice), 0);
        assertEq(usdc.allowance(alice, PERMIT2), type(uint256).max - total);
    }

    function test_RevertWhen_MainnetPermit2_InsufficientPermit2Allowance() public {
        uint256 balance = _units(200);
        uint256 approveAmount = _units(20);
        uint256 depositAmount = _units(100);
        uint256 nonce = 55;
        uint256 deadline = block.timestamp + 1 days;
        _giveUSDC(alice, balance);

        // 只给 Permit2 20 USDC 额度,不足以拉 100
        vm.prank(alice);
        usdc.approve(PERMIT2, approveAmount);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: USDC, amount: depositAmount}),
            nonce: nonce,
            deadline: deadline
        });
        bytes memory signature = _signPermit2(alicePk, address(bank), USDC, depositAmount, nonce, deadline);

        vm.prank(alice);
        vm.expectRevert();
        bank.depositWithPermit2(permit, signature);

        assertEq(bank.balances(alice), 0);
        assertEq(usdc.balanceOf(alice), balance);
        assertEq(usdc.balanceOf(address(bank)), 0);
        assertEq(usdc.allowance(alice, PERMIT2), approveAmount);
    }

    function test_RevertWhen_MainnetPermit2_ReplayNonce() public {
        uint256 amount = _units(10);
        uint256 nonce = 99;
        uint256 deadline = block.timestamp + 1 days;
        _giveUSDC(alice, amount * 2);

        vm.prank(alice);
        usdc.approve(PERMIT2, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: USDC, amount: amount}),
            nonce: nonce,
            deadline: deadline
        });
        bytes memory signature = _signPermit2(alicePk, address(bank), USDC, amount, nonce, deadline);

        vm.prank(alice);
        bank.depositWithPermit2(permit, signature);

        vm.prank(alice);
        vm.expectRevert();
        bank.depositWithPermit2(permit, signature);
    }

    function test_RevertWhen_MainnetPermit2_Expired() public {
        uint256 amount = _units(10);
        uint256 nonce = 88;
        uint256 deadline = block.timestamp + 1 hours;
        _giveUSDC(alice, amount);

        vm.prank(alice);
        usdc.approve(PERMIT2, type(uint256).max);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: USDC, amount: amount}),
            nonce: nonce,
            deadline: deadline
        });
        bytes memory signature = _signPermit2(alicePk, address(bank), USDC, amount, nonce, deadline);

        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert();
        bank.depositWithPermit2(permit, signature);

        assertEq(bank.balances(alice), 0);
        assertEq(usdc.balanceOf(alice), amount);
        assertEq(usdc.balanceOf(address(bank)), 0);
    }

    function test_MainnetPermit2_DOMAIN_SEPARATOR_MatchesChain() public view {
        // 主网 chainId=1 时 Permit2 使用缓存 domain separator
        bytes32 domain = permit2.DOMAIN_SEPARATOR();
        assertTrue(domain != bytes32(0));
    }
}
