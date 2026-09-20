// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseScript} from "../BaseScript.s.sol";
import {LuckyDraw} from "../../src/chainlink_vrf/LuckyDraw.sol";

/// @notice 部署 LuckyDraw（VRF v2.5 Subscription consumer）到目标链。
/// @dev 环境变量：
///   VRF_SUBSCRIPTION_ID  — 必填，vrf.chain.link 上创建的 subscription id
///   VRF_COORDINATOR      — 可选，默认 Sepolia 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
///   VRF_KEY_HASH         — 可选，默认 Sepolia 500 gwei lane
///   VRF_CALLBACK_GAS     — 可选，默认 100000
/// @dev forge script script/chainlink_vrf/DeployLuckyDraw.s.sol --broadcast --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
contract DeployLuckyDrawScript is BaseScript {
    // Sepolia defaults from https://docs.chain.link/vrf/v2-5/getting-started
    address internal constant SEPOLIA_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 internal constant SEPOLIA_KEY_HASH =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 internal constant DEFAULT_CALLBACK_GAS = 100_000;

    function run() public broadcaster {
        uint256 subscriptionId = vm.envUint("VRF_SUBSCRIPTION_ID");
        address coordinator = vm.envOr("VRF_COORDINATOR", SEPOLIA_COORDINATOR);
        bytes32 keyHash = vm.envOr("VRF_KEY_HASH", SEPOLIA_KEY_HASH);
        uint32 callbackGas = uint32(vm.envOr("VRF_CALLBACK_GAS", uint256(DEFAULT_CALLBACK_GAS)));

        LuckyDraw draw = new LuckyDraw(coordinator, subscriptionId, keyHash, callbackGas);
        saveContract("LuckyDraw", address(draw));
    }
}
