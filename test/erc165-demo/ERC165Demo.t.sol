// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {ERC165Checker} from "openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import {IERC1363Receiver} from "openzeppelin-contracts/contracts/interfaces/IERC1363Receiver.sol";
import {IERC1363Spender} from "openzeppelin-contracts/contracts/interfaces/IERC1363Spender.sol";
import {IERC1363} from "openzeppelin-contracts/contracts/interfaces/IERC1363.sol";

import {IGreeter} from "../../src/erc165-demo/IGreeter.sol";
import {GreeterNo165} from "../../src/erc165-demo/GreeterNo165.sol";
import {GreeterWith165} from "../../src/erc165-demo/GreeterWith165.sol";
import {InterfaceProbe} from "../../src/erc165-demo/InterfaceProbe.sol";
import {MyTokenERC1363} from "../../src/MyTokenERC1363.sol";
import {TokenBankERC1363} from "../../src/TokenBankERC1363.sol";

/// @notice ERC-165 教学测试:按用例顺序阅读即可理解标准
contract ERC165DemoTest is Test {
    using ERC165Checker for address;

    GreeterNo165 internal no165;
    GreeterWith165 internal with165;
    InterfaceProbe internal probe;
    address internal eoa = makeAddr("eoa");

    function setUp() public {
        no165 = new GreeterNo165("hi");
        with165 = new GreeterWith165("hello");
        probe = new InterfaceProbe();
    }

    // -------------------------------------------------------------------------
    // 1) interfaceId = 各函数 selector 的 XOR
    // -------------------------------------------------------------------------

    function test_InterfaceId_IsXorOfSelectors() public pure {
        bytes4 greetSel = IGreeter.greet.selector;
        bytes4 setSel = IGreeter.setGreeting.selector;
        bytes4 expected = greetSel ^ setSel;

        // 0xcfae3217 XOR 0xa4136862 = 0x6bbd5a75
        assertEq(type(IGreeter).interfaceId, expected);
        // IERC165 自身: supportsInterface(bytes4) 的 selector = 0x01ffc9a7
        assertEq(type(IERC165).interfaceId, bytes4(0x01ffc9a7));
    }

    // -------------------------------------------------------------------------
    // 2) 正例:声明 IERC165 + IGreeter;0xffffffff 必须为 false
    // -------------------------------------------------------------------------

    function test_GreeterWith165_SupportsExpectedInterfaces() public view {
        assertTrue(with165.supportsInterface(type(IERC165).interfaceId));
        assertTrue(with165.supportsInterface(type(IGreeter).interfaceId));
        assertFalse(with165.supportsInterface(0xffffffff));
        assertFalse(with165.supportsInterface(type(IERC1363).interfaceId));
    }

    // -------------------------------------------------------------------------
    // 3) 反例:有业务函数但没有 ERC-165
    // -------------------------------------------------------------------------

    function test_GreeterNo165_SafeProbeReturnsFalse() public view {
        assertFalse(probe.supportsERC165(address(no165)));
        assertFalse(probe.safeSupportsInterface(address(no165), type(IGreeter).interfaceId));
        // 业务仍可用,只是无法被 ERC-165 探测到
        assertEq(no165.greet(), "hi");
    }

    function test_GreeterNo165_RawProbeReverts() public {
        // 裸调 IERC165.supportsInterface:对方无该 selector → revert
        vm.expectRevert();
        probe.rawSupportsInterface(address(no165), type(IGreeter).interfaceId);
    }

    // -------------------------------------------------------------------------
    // 4) EOA / 无代码地址:Checker 返回 false,不 revert
    // -------------------------------------------------------------------------

    function test_EOA_SafeProbeReturnsFalse_RawReverts() public {
        assertFalse(probe.supportsERC165(eoa));
        assertFalse(probe.safeSupportsInterface(eoa, type(IGreeter).interfaceId));

        vm.expectRevert();
        probe.rawSupportsInterface(eoa, type(IGreeter).interfaceId);
    }

    // -------------------------------------------------------------------------
    // 5) 接到 TokenBank:银行声明 Receiver/Spender;token 声明 IERC1363
    // -------------------------------------------------------------------------

    function test_TokenBank_And_Token_AdvertiseViaERC165() public {
        MyTokenERC1363 token = new MyTokenERC1363();
        TokenBankERC1363 bank = new TokenBankERC1363(token);

        assertTrue(address(token).supportsInterface(type(IERC1363).interfaceId));
        assertTrue(address(bank).supportsInterface(type(IERC165).interfaceId));
        assertTrue(address(bank).supportsInterface(type(IERC1363Receiver).interfaceId));
        assertTrue(address(bank).supportsInterface(type(IERC1363Spender).interfaceId));
        assertFalse(address(bank).supportsInterface(0xffffffff));

        // interfaceId 对单函数接口等于其 selector
        assertEq(type(IERC1363Receiver).interfaceId, IERC1363Receiver.onTransferReceived.selector);
        assertEq(type(IERC1363Spender).interfaceId, IERC1363Spender.onApprovalReceived.selector);
    }
}
