// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC1363} from "openzeppelin-contracts/contracts/interfaces/IERC1363.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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

/// @dev 主网 TetherToken:transfer/approve 不返回 bool,decimals() 返回 uint256(6),非 ERC-1363
interface ITetherToken {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external;
    function transfer(address to, uint256 value) external;
    function decimals() external view returns (uint256);
}

/// @notice fork 以太坊主网,用真实 USDT 走 TokenBankERC1363.deposit
/// @dev 运行:forge test --match-contract TokenBankERC1363MainnetUSDTTest
///      RPC 使用 .env 的 FOUNDRY_RPC_ENDPOINTS.mainnet
contract TokenBankERC1363MainnetUSDTTest is Test {
    /// @dev https://etherscan.io/address/0xdac17f958d2ee523a2206206994597c13d831ec7
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    ITetherToken internal usdt;
    TokenBankERC1363 internal bank;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    function setUp() public {
        // 钉死区块,避免 latest 在公共 RPC 上抖动;deal 不依赖当时持仓
        vm.createSelectFork("mainnet", 25_925_858);

        usdt = ITetherToken(USDT);
        require(USDT.code.length > 0, "USDT not deployed on this fork");
        require(usdt.decimals() == 6, "USDT decimals changed");

        bank = new TokenBankERC1363(IERC20(USDT));
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    /// @dev deal 写入 USDT 余额映射;真实转账走后续 approve + transferFrom
    function _giveUSDT(address to, uint256 amount) internal {
        deal(USDT, to, usdt.balanceOf(to) + amount, true);
    }

    function _units(uint256 wholeTokens) internal view returns (uint256) {
        return wholeTokens * 10 ** usdt.decimals();
    }

    function test_MainnetUSDT_Deposit_ViaApproveAndDeposit() public {
        uint256 amount = _units(100);
        _giveUSDT(alice, amount);

        vm.startPrank(alice);
        usdt.approve(address(bank), amount);

        vm.expectEmit(true, false, false, true, address(bank));
        emit Deposit(alice, amount);
        bank.deposit(amount);
        vm.stopPrank();

        assertEq(bank.balances(alice), amount);
        assertEq(usdt.balanceOf(address(bank)), amount);
        assertEq(usdt.balanceOf(alice), 0);
        assertEq(usdt.allowance(alice, address(bank)), 0);
    }

    function test_MainnetUSDT_Deposit_UsesSixDecimals() public {
        // 100e18 会把 100 枚 USDT 当成 1e14 枚,此处按 decimals() 换算
        uint256 oneHundredUsdt = _units(100);
        assertEq(oneHundredUsdt, 100e6);

        _giveUSDT(alice, oneHundredUsdt);

        vm.startPrank(alice);
        usdt.approve(address(bank), oneHundredUsdt);
        bank.deposit(oneHundredUsdt);
        vm.stopPrank();

        assertEq(bank.balances(alice), 100e6);
        assertEq(usdt.balanceOf(address(bank)), 100e6);
    }

    function test_MainnetUSDT_Deposit_TopUp_Accumulates() public {
        uint256 first = _units(40);
        uint256 second = _units(60);
        _giveUSDT(alice, first + second);

        vm.startPrank(alice);
        usdt.approve(address(bank), first + second);
        bank.deposit(first);
        bank.deposit(second);
        vm.stopPrank();

        assertEq(bank.balances(alice), first + second);
        assertEq(usdt.balanceOf(address(bank)), first + second);
        assertEq(usdt.balanceOf(alice), 0);
    }

    function test_MainnetUSDT_Deposit_MultipleUsers_RecordsIndependently() public {
        uint256 aliceAmt = _units(100);
        uint256 bobAmt = _units(200);
        _giveUSDT(alice, aliceAmt);
        _giveUSDT(bob, bobAmt);

        vm.startPrank(alice);
        usdt.approve(address(bank), aliceAmt);
        bank.deposit(aliceAmt);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(bank), bobAmt);
        bank.deposit(bobAmt);
        vm.stopPrank();

        assertEq(bank.balances(alice), aliceAmt);
        assertEq(bank.balances(bob), bobAmt);
        assertEq(usdt.balanceOf(address(bank)), aliceAmt + bobAmt);
    }

    function test_MainnetUSDT_DepositThenWithdraw_Roundtrip() public {
        uint256 amount = _units(100);
        uint256 withdrawAmount = _units(40);
        _giveUSDT(alice, amount);

        vm.startPrank(alice);
        usdt.approve(address(bank), amount);
        bank.deposit(amount);

        vm.expectEmit(true, false, false, true, address(bank));
        emit Withdraw(alice, withdrawAmount);
        bank.withdraw(withdrawAmount);
        vm.stopPrank();

        assertEq(bank.balances(alice), amount - withdrawAmount);
        assertEq(usdt.balanceOf(alice), withdrawAmount);
        assertEq(usdt.balanceOf(address(bank)), amount - withdrawAmount);
    }

    function test_MainnetUSDT_Deposit_FromWhaleTransfer() public {
        // 常见 USDT 持仓地址(Binance 8);余额不足时 deal 补齐,仍走真实 transfer
        address whale = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
        uint256 amount = _units(1_000);
        if (usdt.balanceOf(whale) < amount) {
            _giveUSDT(whale, amount);
        }

        vm.prank(whale);
        usdt.transfer(alice, amount);
        assertEq(usdt.balanceOf(alice), amount);

        vm.startPrank(alice);
        usdt.approve(address(bank), amount);
        bank.deposit(amount);
        vm.stopPrank();

        assertEq(bank.balances(alice), amount);
        assertEq(usdt.balanceOf(address(bank)), amount);
        assertEq(usdt.balanceOf(alice), 0);
    }

    function test_RevertWhen_MainnetUSDT_DepositZero() public {
        vm.expectRevert("Zero deposit");
        bank.deposit(0);
    }

    function test_RevertWhen_MainnetUSDT_DepositWithoutApproval() public {
        uint256 amount = _units(10);
        _giveUSDT(alice, amount);

        vm.prank(alice);
        vm.expectRevert();
        bank.deposit(amount);
    }

    function test_MainnetUSDT_DoesNotSupportTransferAndCall() public {
        _giveUSDT(alice, _units(1));

        vm.prank(alice);
        (bool ok,) = USDT.call(abi.encodeWithSignature("transferAndCall(address,uint256)", address(bank), _units(1)));
        assertFalse(ok, "USDT is not ERC-1363; only approve + deposit works");
        assertEq(bank.balances(alice), 0);
        assertEq(usdt.balanceOf(address(bank)), 0);
    }
}

