// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice 将已部署的 UUPS 代理升级到 UUPSCounterV2。
/// @dev 代理地址优先读环境变量 `PROXY`；未设置则读
///      `deployments/UUPSCounter/UUPSCounter_<chainId>.json`。
///      广播账户必须是代理上的 owner。
contract UUPSCounterV2Script is BaseScript {
    function run() public broadcaster {
        address proxy = _resolveProxy();

        // Upgrades.upgradeProxy 内部顺序：
        // 1) ffi 校验 V2 相对 V1（@custom:oz-upgrades-from）的存储布局
        // 2) 部署 V2 implementation
        // 3) 由当前广播账户调用 proxy.upgradeToAndCall（UUPS：admin slot 为空）
        Upgrades.upgradeProxy(proxy, "UUPSCounterV2.sol:UUPSCounterV2", "");

        saveContract("UUPSCounter", proxy);
        saveContract("UUPSCounter_Implementation", Upgrades.getImplementationAddress(proxy));
    }

    function _resolveProxy() internal view returns (address proxy) {
        try vm.envAddress("PROXY") returns (address fromEnv) {
            return fromEnv;
        } catch {
            string memory path = string.concat(
                "deployments/UUPSCounter/UUPSCounter_", vm.toString(block.chainid), ".json"
            );
            return vm.parseJsonAddress(vm.readFile(path), ".address");
        }
    }
}
