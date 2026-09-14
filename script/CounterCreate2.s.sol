// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 经 Arachnid CREATE2 factory 部署 Counter,跨链同址
/// @dev 地址公式（EIP-1014）：
///      keccak256(0xff ++ factory ++ salt ++ keccak256(initcode))[12:]
///      factory 是各链同址的 0x4e59…（Foundry CREATE2_FACTORY）。
///      三条测试网用同一 salt、同一编译产物、同一构造参数 → 同一地址。
contract CounterCreate2Script is BaseScript {
    /// @dev salt 公开,不是密钥。同一 (factory, salt, initcode) 只能成功一次。
    bytes32 public constant SALT = keccak256("lbc-2026s3:Counter");
    uint256 public constant INITIAL_NUMBER = 20;

    Counter public counter;

    function run() public broadcaster {
        // CREATE2_FACTORY == 0x4e59b44847b379578588920cA78FbF26c0B4956C
        // EOA 不能发 CREATE2 opcode,必须 call 这个已在各链同址的 factory。
        require(CREATE2_FACTORY.code.length != 0, "CREATE2 factory missing on this chain");

        // initcode = creation bytecode || abi.encode(constructor args)
        // 编译器版本、optimizer、构造参数任一变化,hash 变,地址就变。
        bytes memory initCode = abi.encodePacked(type(Counter).creationCode, abi.encode(INITIAL_NUMBER));
        // 第三参必须传 factory。省略时 forge-std 也默认 0x4e59…,但单测里 `new {salt:}` 的 sender 是测试合约。
        address predicted = vm.computeCreate2Address(SALT, keccak256(initCode), CREATE2_FACTORY);

        if (predicted.code.length != 0) {
            // 该槽已被同一 initcode 占住（本脚本上次部署,或别人用同一 salt+initcode 先发）。
            // 换一份恶意 bytecode 算不出这个地址,所以这里的代码就是这份 Counter。
            counter = Counter(predicted);
            console.log("Counter already deployed at CREATE2 address");
        } else {
            // Arachnid proxy 的 calldata = salt (32 bytes) || initcode。
            // CREATE2 的 sender 是 factory,不是本脚本 / 广播 EOA。
            // 不用 `new Counter{salt:}`：forge 把它改写成 factory call 在部分 L2（如 OP Sepolia）上会走偏。
            (bool success, bytes memory data) = CREATE2_FACTORY.call(abi.encodePacked(SALT, initCode));
            require(success, "CREATE2 factory call failed");
            // factory 返回 20 字节地址（不是 32 字节左填充）。
            require(data.length == 20, "CREATE2 factory bad returndata");
            address deployed = address(bytes20(data));
            require(deployed == predicted, "CREATE2 address mismatch");
            counter = Counter(deployed);
            require(counter.number() == INITIAL_NUMBER, "Counter init mismatch");
        }

        console.log("CREATE2 factory", CREATE2_FACTORY);
        console.log("Counter (CREATE2)", address(counter));
        console.log("predicted Counter", predicted);
        console.log("chainId", block.chainid);

        saveContract("CounterCreate2", address(counter));
    }
}
