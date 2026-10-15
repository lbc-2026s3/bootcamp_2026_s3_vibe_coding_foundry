// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {InlineCalculator} from "../../src/library_demo/InlineCalculator.sol";
import {LinkedCalculator} from "../../src/library_demo/LinkedCalculator.sol";

interface ILinkedMath {
    function add(uint256 a, uint256 b) external pure returns (uint256);
    function readSlot0() external view returns (uint256);
}

/// @notice 对照 internal 内联和 public 库 link。
///         forge test --match-path test/library_demo/LibraryLink.t.sol -vvvv
contract LibraryLinkTest is Test {
    InlineCalculator internal inlineCalc;
    LinkedCalculator internal linkedCalc;

    function setUp() public {
        inlineCalc = new InlineCalculator();
        linkedCalc = new LinkedCalculator();
    }

    function test_inline_add_has_no_delegatecall() public view {
        assertEq(inlineCalc.calculate(1, 2), 3);

        (bool found,) = _delegatecallTarget(address(inlineCalc).code);
        assertFalse(found);
    }

    function test_linked_add_delegatecalls_library() public view {
        assertEq(linkedCalc.calculate(1, 2), 3);

        (bool found, address lib) = _delegatecallTarget(address(linkedCalc).code);
        assertTrue(found);
        assertTrue(lib.code.length > 0);
        assertEq(ILinkedMath(lib).add(1, 2), 3);
    }

    /// @dev delegatecall 写入调用方 slot 0。库自己的 slot 0 保持 0。
    ///      直接 CALL writeSlot0 会被编译器插进的保护拒绝：address(this) 等于库地址时，改状态的函数直接 revert。
    function test_linked_write_hits_caller_storage() public {
        linkedCalc.increment();
        assertEq(linkedCalc.counter(), 1);

        (, address lib) = _delegatecallTarget(address(linkedCalc).code);
        assertEq(ILinkedMath(lib).readSlot0(), 0);
    }

    function test_inline_increment_updates_own_storage() public {
        inlineCalc.increment();
        assertEq(inlineCalc.counter(), 1);
    }

    /// @dev 去掉 solidity metadata 后按 opcode 走一遍，避免 PUSH 立即数或 metadata 里的 0xf4 被误认。
    function _delegatecallTarget(bytes memory code) private pure returns (bool found, address target) {
        code = _stripMetadata(code);
        address latestPush20;
        bool hasPush20;

        for (uint256 i = 0; i < code.length;) {
            uint8 op = uint8(code[i]);
            if (op >= 0x60 && op <= 0x7f) {
                uint256 n = uint256(op) - 0x5f;
                if (op == 0x73) {
                    latestPush20 = _readAddress(code, i + 1);
                    hasPush20 = true;
                }
                i += 1 + n;
                continue;
            }
            if (op == 0xf4 && hasPush20) {
                return (true, latestPush20);
            }
            unchecked {
                ++i;
            }
        }
        return (false, address(0));
    }

    function _readAddress(bytes memory code, uint256 offset) private pure returns (address addr) {
        assembly {
            addr := shr(96, mload(add(add(code, 0x20), offset)))
        }
    }

    function _stripMetadata(bytes memory code) private pure returns (bytes memory) {
        bytes memory marker = hex"a2646970667358221220";
        if (code.length < marker.length) return code;

        uint256 cut = code.length;
        for (uint256 i = 0; i + marker.length <= code.length; ++i) {
            bool matched = true;
            for (uint256 j = 0; j < marker.length; ++j) {
                if (code[i + j] != marker[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) {
                cut = i;
                break;
            }
        }
        if (cut == code.length) return code;

        bytes memory trimmed = new bytes(cut);
        for (uint256 k = 0; k < cut; ++k) {
            trimmed[k] = code[k];
        }
        return trimmed;
    }
}
