// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MyERC721UpgradeableNFTV2} from "../../src/upgradeable/MyERC721UpgradeableNFTV2.sol";
import {BaseScript} from "../BaseScript.s.sol";

/// @notice 将已部署的 UUPS 代理升级到 MyERC721UpgradeableNFTV2，并调用 initializeV2
/// @dev 代理地址优先读环境变量 `PROXY`；未设置则读
///      `deployments/MyERC721UpgradeableNFT/MyERC721UpgradeableNFT_<chainId>.json`
contract MyERC721UpgradeableNFTV2Script is BaseScript {
    MyERC721UpgradeableNFTV2 public nft;

    function run() public broadcaster {
        address proxy = _resolveProxy();

        // Upgrades.upgradeProxy 内部顺序：
        // 1) ffi 校验 V2 相对 V1（@custom:oz-upgrades-from）的存储布局兼容性
        // 2) 部署 V2 implementation
        // 3) 由 owner 调用 proxy.upgradeToAndCall(impl, initializeV2)
        Upgrades.upgradeProxy(
            proxy,
            "MyERC721UpgradeableNFTV2.sol:MyERC721UpgradeableNFTV2",
            abi.encodeCall(MyERC721UpgradeableNFTV2.initializeV2, ())
        );

        nft = MyERC721UpgradeableNFTV2(proxy);

        // proxy 地址不变；刷新 LATEST 与新 implementation 记录
        saveContract("MyERC721UpgradeableNFT", proxy);
        saveContract("MyERC721UpgradeableNFT_Implementation", Upgrades.getImplementationAddress(proxy));
    }

    function _resolveProxy() internal view returns (address proxy) {
        try vm.envAddress("PROXY") returns (address fromEnv) {
            return fromEnv;
        } catch {
            string memory path = string.concat(
                "deployments/MyERC721UpgradeableNFT/MyERC721UpgradeableNFT_",
                vm.toString(block.chainid),
                ".json"
            );
            return vm.parseJsonAddress(vm.readFile(path), ".address");
        }
    }
}
