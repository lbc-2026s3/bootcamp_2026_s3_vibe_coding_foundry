// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {UUPSCounter} from "../../../src/upgradeable/uups/UUPSCounter.sol";
import {UUPSCounterV2} from "../../../src/upgradeable/uups/UUPSCounterV2.sol";

contract UUPSCounterTest is Test {
    UUPSCounter internal counter;
    UUPSCounter internal implementation;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");

    function setUp() public {
        implementation = new UUPSCounter();
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            address(implementation), abi.encodeCall(UUPSCounter.initialize, (1, owner))
        );
        counter = UUPSCounter(proxy);
    }

    function test_Initialize_SetsNumberAndOwner() public view {
        assertEq(counter.number(), 1);
        assertEq(counter.owner(), owner);
        assertEq(counter.version(), 1);
        assertEq(UnsafeUpgrades.getImplementationAddress(address(counter)), address(implementation));
        assertEq(UnsafeUpgrades.getAdminAddress(address(counter)), address(0));
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
        counter.initialize(9, alice);
    }

    function test_RevertWhen_InitializeImplementation() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(9, owner);
    }

    function test_Upgrade_PreservesStateAndEnablesDecrement() public {
        counter.increment();
        assertEq(counter.number(), 2);

        UUPSCounterV2 v2 = new UUPSCounterV2();
        vm.prank(owner);
        counter.upgradeToAndCall(address(v2), "");

        UUPSCounterV2 upgraded = UUPSCounterV2(address(counter));
        assertEq(address(upgraded), address(counter));
        assertEq(UnsafeUpgrades.getImplementationAddress(address(counter)), address(v2));
        assertEq(upgraded.number(), 2);
        assertEq(upgraded.owner(), owner);
        assertEq(upgraded.version(), 2);
        assertEq(upgraded.decrements(), 0);

        upgraded.decrement();
        assertEq(upgraded.number(), 1);
        assertEq(upgraded.decrements(), 1);
    }

    function test_RevertWhen_NonOwnerUpgrade() public {
        UUPSCounterV2 v2 = new UUPSCounterV2();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        counter.upgradeToAndCall(address(v2), "");
    }

    function test_RevertWhen_UpgradeCalledOnImplementation() public {
        UUPSCounterV2 v2 = new UUPSCounterV2();
        vm.expectRevert(UUPSUpgradeable.UUPSUnauthorizedCallContext.selector);
        implementation.upgradeToAndCall(address(v2), "");
    }
}
