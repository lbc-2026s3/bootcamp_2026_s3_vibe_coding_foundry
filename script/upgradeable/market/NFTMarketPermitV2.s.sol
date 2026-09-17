// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {NFTMarketPermitV2} from "../../../src/upgradeable/market/NFTMarketPermitV2.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice 将已部署的 UUPS 代理从 NFTMarketPermitV1 升级到 V2，并调用 initializeV2
/// @dev 代理地址优先读环境变量 `PROXY`；未设置则读
///      `deployments/NFTMarketPermitV1/NFTMarketPermitV1_<chainId>.json`
contract NFTMarketPermitV2Script is BaseScript {
    NFTMarketPermitV2 public market;

    function run() public broadcaster {
        address proxy = _resolveProxy();

        Options memory opts;
        // OZ ReentrancyGuard（@custom:stateless）有 constructor；validator 尚未豁免
        opts.unsafeAllow = "constructor";

        // Upgrades.upgradeProxy：校验 V2↔V1 布局 → 部署 V2 impl → owner.upgradeToAndCall(initializeV2)
        Upgrades.upgradeProxy(
            proxy,
            "NFTMarketPermitV2.sol:NFTMarketPermitV2",
            abi.encodeCall(NFTMarketPermitV2.initializeV2, ()),
            opts
        );

        market = NFTMarketPermitV2(proxy);

        // proxy 地址不变：继续更新 V1 记录便于后续脚本解析；同时记下 V2 与新 implementation
        saveContract("NFTMarketPermitV1", proxy);
        saveContract("NFTMarketPermitV2", proxy);
        saveContract("NFTMarketPermitV2_Implementation", Upgrades.getImplementationAddress(proxy));
    }

    function _resolveProxy() internal view returns (address proxy) {
        try vm.envAddress("PROXY") returns (address fromEnv) {
            return fromEnv;
        } catch {
            string memory path = string.concat(
                "deployments/NFTMarketPermitV1/NFTMarketPermitV1_", vm.toString(block.chainid), ".json"
            );
            return vm.parseJsonAddress(vm.readFile(path), ".address");
        }
    }
}
