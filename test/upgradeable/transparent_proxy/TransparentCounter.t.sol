// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ITransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TransparentCounter} from "../../../src/upgradeable/transparent_proxy/TransparentCounter.sol";
import {TransparentCounterV2} from "../../../src/upgradeable/transparent_proxy/TransparentCounterV2.sol";

contract TransparentCounterTest is Test {
    TransparentCounter internal counter;
    TransparentCounter internal implementation;
    ProxyAdmin internal proxyAdmin;

    address internal adminOwner = makeAddr("adminOwner");
    address internal alice = makeAddr("alice");

    function setUp() public {
        implementation = new TransparentCounter();
        address proxy = UnsafeUpgrades.deployTransparentProxy(
            address(implementation), adminOwner, abi.encodeCall(TransparentCounter.initialize, (1))
        );
        counter = TransparentCounter(proxy);
        proxyAdmin = ProxyAdmin(UnsafeUpgrades.getAdminAddress(proxy));
    }

    function test_Initialize_SetsNumberAndSeparateAdmin() public view {
        assertEq(counter.number(), 1);
        assertEq(counter.version(), 1);
        assertEq(UnsafeUpgrades.getImplementationAddress(address(counter)), address(implementation));
        assertEq(proxyAdmin.owner(), adminOwner);
        assertTrue(address(proxyAdmin) != adminOwner);
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 2);
    }

    function test_StateLivesOnProxy() public {
        counter.increment();
        assertEq(counter.number(), 2);
        assertEq(implementation.number(), 0);
    }

    function test_RevertWhen_InitializeTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        counter.initialize(9);
    }

    function test_RevertWhen_InitializeImplementation() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(9);
    }

    function test_RevertWhen_ProxyAdminCallsImplementation() public {
        vm.prank(address(proxyAdmin));
        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        counter.increment();
    }

    function test_Upgrade_PreservesStateAndEnablesDecrement() public {
        counter.increment();
        assertEq(counter.number(), 2);

        TransparentCounterV2 v2 = new TransparentCounterV2();
        vm.prank(adminOwner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(counter)), address(v2), "");

        TransparentCounterV2 upgraded = TransparentCounterV2(address(counter));
        assertEq(address(upgraded), address(counter));
        assertEq(UnsafeUpgrades.getImplementationAddress(address(counter)), address(v2));
        assertEq(UnsafeUpgrades.getAdminAddress(address(counter)), address(proxyAdmin));
        assertEq(upgraded.number(), 2);
        assertEq(upgraded.version(), 2);
        assertEq(upgraded.decrements(), 0);

        upgraded.decrement();
        assertEq(upgraded.number(), 1);
        assertEq(upgraded.decrements(), 1);
    }

    function test_RevertWhen_NonOwnerUpgrade() public {
        TransparentCounterV2 v2 = new TransparentCounterV2();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(counter)), address(v2), "");
    }

    function test_RevertWhen_UserCallsUpgradeSelectorOnProxy() public {
        TransparentCounterV2 v2 = new TransparentCounterV2();
        // 普通用户的 upgradeToAndCall 会转发给实现合约；V1 没有这个函数，调用失败。
        vm.prank(alice);
        (bool ok,) = address(counter).call(
            abi.encodeCall(ITransparentUpgradeableProxy.upgradeToAndCall, (address(v2), ""))
        );
        assertFalse(ok);
        assertEq(counter.version(), 1);
        assertEq(UnsafeUpgrades.getImplementationAddress(address(counter)), address(implementation));
    }
}
