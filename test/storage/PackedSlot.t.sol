// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {PackedSlot} from "../../src/storage/PackedSlot.sol";

/// @dev 与 src/Test.sol 相同的槽位和构造初值。
///      不直接 new 那个合约：它的名字和 forge-std 的 Test 撞车，动态链接按名字找 artifact 会失败。
contract OptimizedLayout {
    struct Optimized {
        uint128 a;
        uint128 c;
        address b;
    }

    Optimized public a;
    mapping(address => uint256) public balances;

    address public constant DEMO_ACCOUNT = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint128 public constant INITIAL_A = 42;
    uint128 public constant INITIAL_C = 7;

    constructor() {
        a = Optimized({a: INITIAL_A, c: INITIAL_C, b: DEMO_ACCOUNT});
    }
}

/// @notice forge test --match-path test/storage/PackedSlot.t.sol -vv
contract PackedSlotTest is Test {
    uint64 internal constant X = 0x1111;
    uint64 internal constant Y = 0x2222;
    uint128 internal constant Z = 0x3333;

    bytes32 internal constant PACKED_WORD = hex"0000000000000000000000000000333300000000000022220000000000001111";

    function test_unpack_three_variables_from_one_slot() public {
        PackedSlot packed = new PackedSlot(X, Y, Z);

        bytes32 word = packed.raw();
        console2.logBytes32(word);
        assertEq(word, PACKED_WORD);

        (uint64 x, uint64 y, uint128 z) = packed.unpack();
        assertEq(x, X);
        assertEq(y, Y);
        assertEq(z, Z);

        bytes memory laidOut = _asMemoryBytes(uint256(word));
        assertEq(laidOut.length, 32);
        assertEq(keccak256(laidOut), keccak256(abi.encodePacked(PACKED_WORD)));
        // 低地址是 z 的最高字节；高地址是 x 的最低字节。
        assertEq(uint8(laidOut[0]), 0x00);
        assertEq(uint8(laidOut[14]), 0x33);
        assertEq(uint8(laidOut[15]), 0x33);
        assertEq(uint8(laidOut[22]), 0x22);
        assertEq(uint8(laidOut[23]), 0x22);
        assertEq(uint8(laidOut[30]), 0x11);
        assertEq(uint8(laidOut[31]), 0x11);
    }

    function test_Test_slots_match_big_endian_words() public {
        OptimizedLayout demo = new OptimizedLayout();

        bytes32 slot0 = vm.load(address(demo), 0);
        bytes32 slot1 = vm.load(address(demo), bytes32(uint256(1)));
        console2.logBytes32(slot0);
        console2.logBytes32(slot1);

        assertEq(slot0, hex"000000000000000000000000000000070000000000000000000000000000002a");
        assertEq(slot1, hex"00000000000000000000000070997970C51812dc3A010C7d01b50e0d17dc79C8");

        uint256 head = uint256(slot0);
        assertEq(uint128(head), demo.INITIAL_A());
        assertEq(uint128(head >> 128), demo.INITIAL_C());
        assertEq(address(uint160(uint256(slot1))), demo.DEMO_ACCOUNT());
    }

    /// @dev MSTORE 把 256 位字按大端写入内存：memory[p] 是最高字节。
    function _asMemoryBytes(uint256 word) internal pure returns (bytes memory out) {
        out = new bytes(32);
        assembly {
            mstore(add(out, 0x20), word)
        }
    }
}
