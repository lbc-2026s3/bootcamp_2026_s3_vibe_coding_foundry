// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseScript} from "../BaseScript.s.sol";
import {MessageMailbox} from "../../src/crosschain_message/MessageMailbox.sol";
import {RemoteCounter} from "../../src/crosschain_message/RemoteCounter.sol";

/// @notice 在同一条链上部署两个 Mailbox + 一个 RemoteCounter（逻辑 domain 模拟双链）。
/// @dev 环境变量：
///   MESSAGE_RELAYER — 可选，默认部署者自己当 relayer
///   MESSAGE_HOME    — 可选，默认 1
///   MESSAGE_REMOTE  — 可选，默认 2
/// @dev forge script script/crosschain_message/DeployMessage.s.sol --broadcast \
///      --rpc-url local --private-key $LOCAL_PRIVATE_KEY && cat ./deployments/LATEST.txt
contract DeployMessageScript is BaseScript {
    uint64 internal constant DEFAULT_HOME = 1;
    uint64 internal constant DEFAULT_REMOTE = 2;

    function run() public broadcaster {
        uint64 home = uint64(vm.envOr("MESSAGE_HOME", uint256(DEFAULT_HOME)));
        uint64 remote = uint64(vm.envOr("MESSAGE_REMOTE", uint256(DEFAULT_REMOTE)));
        address relayer = vm.envOr("MESSAGE_RELAYER", deployer);

        MessageMailbox srcMailbox = new MessageMailbox(home, remote, relayer, deployer);
        MessageMailbox destMailbox = new MessageMailbox(remote, home, relayer, deployer);
        RemoteCounter counter = new RemoteCounter(address(destMailbox));

        saveContract("SourceMailbox", address(srcMailbox));
        saveContract("DestMailbox", address(destMailbox));
        saveContract("RemoteCounter", address(counter));
    }
}
