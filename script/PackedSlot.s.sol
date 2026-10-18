// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// forge script script/PackedSlot.s.sol --rpc-url local --broadcast \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt

import {console} from "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.s.sol";
import {PackedSlot} from "../src/storage/PackedSlot.sol";

/// @notice 部署 PackedSlot，初值与 docs/evm-storage-endian.md 的例子相同。
/// 槽 0 应为 0x0000000000000000000000000000333300000000000022220000000000001111
contract DeployPackedSlot is BaseScript {
    uint64 internal constant X = 0x1111;
    uint64 internal constant Y = 0x2222;
    uint128 internal constant Z = 0x3333;

    function run() public broadcaster {
        PackedSlot packed = new PackedSlot(X, Y, Z);
        saveContract("PackedSlot", address(packed));

        console.log("PackedSlot:", address(packed));
        console.log("x:", packed.x());
        console.log("y:", packed.y());
        console.log("z:", packed.z());
        console.log("slot0:");
        console.logBytes32(vm.load(address(packed), 0));
    }
}
