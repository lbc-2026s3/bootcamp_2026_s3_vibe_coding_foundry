// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice 将已部署的透明代理升级到 TransparentCounterV2。
/// @dev 代理地址优先读环境变量 `PROXY`；未设置则读
///      `deployments/TransparentCounter/TransparentCounter_<chainId>.json`。
///      广播账户必须是 ProxyAdmin 的 owner。插件会改调 ProxyAdmin.upgradeAndCall，而不是代理上的业务函数。
contract TransparentCounterV2Script is BaseScript {
    function run() public broadcaster {
        address proxy = _resolveProxy();

        // 1) ffi 校验 V2 相对 V1 的存储布局
        // 2) 部署 V2 implementation
        // 3) 读 ERC-1967 admin slot，由 ProxyAdmin owner 调用 upgradeAndCall
        Upgrades.upgradeProxy(proxy, "TransparentCounterV2.sol:TransparentCounterV2", "");

        saveContract("TransparentCounter", proxy);
        saveContract("TransparentCounter_Implementation", Upgrades.getImplementationAddress(proxy));
        saveContract("TransparentCounter_ProxyAdmin", Upgrades.getAdminAddress(proxy));
    }

    function _resolveProxy() internal view returns (address proxy) {
        try vm.envAddress("PROXY") returns (address fromEnv) {
            return fromEnv;
        } catch {
            string memory path = string.concat(
                "deployments/TransparentCounter/TransparentCounter_", vm.toString(block.chainid), ".json"
            );
            return vm.parseJsonAddress(vm.readFile(path), ".address");
        }
    }
}
