// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {TransparentCounter} from "../../../src/upgradeable/transparent_proxy/TransparentCounter.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice 用 OpenZeppelin Foundry Upgrades 部署透明代理版 TransparentCounter。
contract TransparentCounterScript is BaseScript {
    uint256 public constant INITIAL_NUMBER = 0;

    TransparentCounter public counter;

    function run() public broadcaster {
        // Upgrades.deployTransparentProxy 内部顺序：
        // 1) ffi 校验实现合约升级安全
        // 2) 部署 implementation
        // 3) 部署 TransparentUpgradeableProxy(impl, initialOwner, initializerData)
        //    代理构造时会 new 一个 ProxyAdmin，并把 initialOwner 设为该 ProxyAdmin 的 owner
        //    业务调用走代理 delegatecall；升级只能由 ProxyAdmin.upgradeAndCall 发起
        address proxy = Upgrades.deployTransparentProxy(
            "TransparentCounter.sol:TransparentCounter",
            deployer,
            abi.encodeCall(TransparentCounter.initialize, (INITIAL_NUMBER))
        );
        counter = TransparentCounter(proxy);

        saveContract("TransparentCounter", proxy);
        saveContract("TransparentCounter_Implementation", Upgrades.getImplementationAddress(proxy));
        saveContract("TransparentCounter_ProxyAdmin", Upgrades.getAdminAddress(proxy));
    }
}
