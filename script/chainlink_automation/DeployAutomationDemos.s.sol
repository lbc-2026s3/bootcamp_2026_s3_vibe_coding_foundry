// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseScript} from "../BaseScript.s.sol";
import {HeartbeatCounter} from "../../src/chainlink_automation/heartbeat/HeartbeatCounter.sol";
import {ArmedCounter} from "../../src/chainlink_automation/armed/ArmedCounter.sol";
import {LogTriggeredCounter} from "../../src/chainlink_automation/log_trigger/LogTriggeredCounter.sol";

/// @notice 一次部署三个 Automation/CRE demo 目标合约。
/// @dev forge script script/chainlink_automation/DeployAutomationDemos.s.sol --broadcast --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
contract DeployAutomationDemosScript is BaseScript {
    function run() public broadcaster {
        HeartbeatCounter heartbeat = new HeartbeatCounter();
        ArmedCounter armed = new ArmedCounter();
        LogTriggeredCounter logTrigger = new LogTriggeredCounter();

        saveContract("HeartbeatCounter", address(heartbeat));
        saveContract("ArmedCounter", address(armed));
        saveContract("LogTriggeredCounter", address(logTrigger));
    }
}
