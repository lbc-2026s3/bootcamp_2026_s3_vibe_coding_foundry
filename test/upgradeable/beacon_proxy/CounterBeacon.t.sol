// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Counter} from "../../../src/upgradeable/beacon_proxy/Counter.sol";
import {CounterV2} from "../../../src/upgradeable/beacon_proxy/CounterV2.sol";
import {CounterBeaconFactory} from "../../../src/upgradeable/beacon_proxy/CounterBeaconFactory.sol";

contract CounterBeaconTest is Test {
    address internal owner = makeAddr("owner");
    address internal stranger = makeAddr("stranger");

    CounterBeaconFactory internal factory;
    UpgradeableBeacon internal beacon;

    function setUp() public {
        vm.prank(owner);
        factory = new CounterBeaconFactory(owner);
        beacon = factory.beacon();
    }

    function test_CreateCounter_InitializesAndSharesBeacon() public {
        address proxy = factory.createCounter(42);
        Counter counter = Counter(proxy);

        assertEq(counter.number(), 42);
        assertTrue(beacon.implementation().code.length > 0);
        assertEq(beacon.owner(), address(factory));
    }

    function test_MultipleProxies_IndependentStorage() public {
        address a = factory.createCounter(1);
        address b = factory.createCounter(100);

        assertTrue(a != b);
        assertEq(Counter(a).number(), 1);
        assertEq(Counter(b).number(), 100);

        Counter(a).increment();
        assertEq(Counter(a).number(), 2);
        assertEq(Counter(b).number(), 100);
    }

    function test_UpgradeTo_V2_AppliesToAllProxies() public {
        address a = factory.createCounter(5);
        address b = factory.createCounter(10);

        Counter(a).increment();
        assertEq(Counter(a).number(), 6);
        assertEq(Counter(b).number(), 10);

        CounterV2 v2 = new CounterV2();
        address v1 = beacon.implementation();
        vm.prank(owner);
        factory.upgradeTo(address(v2));

        assertEq(beacon.implementation(), address(v2));
        assertTrue(v1 != address(v2));

        // 旧 storage 保留
        assertEq(CounterV2(a).number(), 6);
        assertEq(CounterV2(b).number(), 10);

        // 一次升级后，所有已有 proxy 都能用 V2 新函数
        CounterV2(a).decrement();
        CounterV2(b).decrement();
        assertEq(CounterV2(a).number(), 5);
        assertEq(CounterV2(b).number(), 9);
    }

    function test_CreateCounter_AfterUpgrade_UsesV2() public {
        CounterV2 v2 = new CounterV2();
        vm.prank(owner);
        factory.upgradeTo(address(v2));

        address proxy = factory.createCounter(3);
        assertEq(CounterV2(proxy).number(), 3);
        CounterV2(proxy).decrement();
        assertEq(CounterV2(proxy).number(), 2);
    }

    function test_RevertWhen_NonOwnerUpgrade() public {
        CounterV2 v2 = new CounterV2();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        factory.upgradeTo(address(v2));
    }

    function test_RevertWhen_DirectBeaconUpgradeByStranger() public {
        CounterV2 v2 = new CounterV2();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        beacon.upgradeTo(address(v2));
    }

    function test_RevertWhen_ReinitializeProxy() public {
        address proxy = factory.createCounter(0);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        Counter(proxy).initialize(99);
    }

    function test_RevertWhen_InitializeImplementation() public {
        Counter impl = Counter(beacon.implementation());
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        impl.initialize(1);
    }
}
