// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {UUPSCounter} from "../../../src/upgradeable/uups/UUPSCounter.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice 用 OpenZeppelin Foundry Upgrades 部署 UUPS 代理版 UUPSCounter。
contract UUPSCounterScript is BaseScript {
    uint256 public constant INITIAL_NUMBER = 0;

    UUPSCounter public counter;

    function run() public broadcaster {
        // Upgrades.deployUUPSProxy 内部顺序：
        // 1) ffi 调 `@openzeppelin/upgrades-core validate`，检查实现是否升级安全
        // 2) 部署 implementation（constructor 里 `_disableInitializers()`）
        // 3) 部署 ERC1967Proxy(impl, initializerData)；proxy 构造时 delegatecall 到 initialize
        //    升级函数在实现合约上，之后由 owner 对 proxy 调 upgradeToAndCall
        address proxy = Upgrades.deployUUPSProxy(
            "UUPSCounter.sol:UUPSCounter",
            abi.encodeCall(UUPSCounter.initialize, (INITIAL_NUMBER, deployer))
        );
        counter = UUPSCounter(proxy);

        saveContract("UUPSCounter", proxy);
        saveContract("UUPSCounter_Implementation", Upgrades.getImplementationAddress(proxy));
    }
}
