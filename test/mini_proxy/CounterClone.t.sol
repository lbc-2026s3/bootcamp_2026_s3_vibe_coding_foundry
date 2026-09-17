// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {Counter} from "../../src/mini_proxy/Counter.sol";
import {CounterCloneFactory} from "../../src/mini_proxy/CounterCloneFactory.sol";

contract CounterCloneTest is Test {
    CounterCloneFactory internal factory;

    function setUp() public {
        factory = new CounterCloneFactory();
    }

    /// @dev 从 EIP-1167 runtime bytecode 抠出 implementation 地址（45 字节）。
    function _cloneImplementation(address clone) private view returns (address impl) {
        bytes memory code = clone.code;
        require(code.length == 45, "not eip-1167 runtime");
        assembly {
            impl := shr(96, mload(add(code, 42)))
        }
    }

    function test_CreateCounter_UsesMinimalProxy() public {
        address proxy = factory.createCounter(42);
        Counter counter = Counter(proxy);

        assertEq(proxy.code.length, 45);
        assertEq(_cloneImplementation(proxy), factory.implementation());
        assertEq(counter.number(), 42);
    }

    function test_MultipleProxies_ShareOneImplementation() public {
        address a = factory.createCounter(1);
        address b = factory.createCounter(100);

        assertTrue(a != b);
        assertEq(keccak256(a.code), keccak256(b.code));
        assertEq(_cloneImplementation(a), _cloneImplementation(b));
        assertEq(Counter(a).number(), 1);
        assertEq(Counter(b).number(), 100);

        Counter(a).increment();
        assertEq(Counter(a).number(), 2);
        assertEq(Counter(b).number(), 100);
    }

    function test_CreateCounterDeterministic_PredictableAddress() public {
        bytes32 salt = keccak256("counter-1");
        address predicted = factory.predictAddress(salt);

        address proxy = factory.createCounterDeterministic(7, salt);
        assertEq(proxy, predicted);
        assertEq(Counter(proxy).number(), 7);
        assertEq(factory.implementation(), _cloneImplementation(proxy));
    }

    function test_RevertWhen_ReinitializeProxy() public {
        address proxy = factory.createCounter(0);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        Counter(proxy).initialize(99);
    }

    function test_RevertWhen_InitializeImplementation() public {
        Counter impl = Counter(factory.implementation());
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        impl.initialize(1);
    }
}
