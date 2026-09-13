// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";
import {Counter} from "../src/Counter.sol";
import {Create3Factory} from "../src/Create3Factory.sol";

contract Create3FactoryTest is Test {
    Create3Factory internal factory;

    bytes32 internal constant SALT = keccak256("lbc-2026s3:Counter");

    function _deployCounter(bytes32 salt, uint256 initialNumber) private returns (Counter) {
        address deployed = factory.deploy(salt, _creationCode(initialNumber));
        return Counter(deployed);
    }

    function _creationCode(uint256 initialNumber) private pure returns (bytes memory) {
        return abi.encodePacked(type(Counter).creationCode, abi.encode(initialNumber));
    }

    function _create2Address(bytes32 salt, bytes memory creationCode) private view returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(creationCode)))))
        );
    }

    function setUp() public {
        factory = new Create3Factory();
    }

    function test_DeployCounter_MatchesPredictedAddress() public {
        address predicted = factory.getDeployed(SALT);
        Counter counter = _deployCounter(SALT, 42);

        assertEq(address(counter), predicted);
        assertEq(counter.number(), 42);
    }

    function test_DeployCounter_IncrementWorks() public {
        Counter counter = _deployCounter(SALT, 0);
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function test_PredictedAddress_IndependentOfCreationCode() public {
        address predictedZero = factory.getDeployed(SALT);
        address predictedFortyTwo = factory.getDeployed(SALT);

        assertEq(predictedZero, predictedFortyTwo);

        // CREATE2 会把 initcode hash 算进地址,构造参数不同则地址不同
        assertTrue(_create2Address(SALT, _creationCode(0)) != _create2Address(SALT, _creationCode(42)));
    }

    function test_DifferentSalt_DifferentAddress() public {
        Counter a = _deployCounter(keccak256("salt-a"), 1);
        Counter b = _deployCounter(keccak256("salt-b"), 1);

        assertTrue(address(a) != address(b));
        assertEq(a.number(), 1);
        assertEq(b.number(), 1);
    }

    function test_RevertWhen_SameSaltUsedTwice() public {
        _deployCounter(SALT, 0);

        vm.expectRevert("DEPLOYMENT_FAILED");
        factory.deploy(SALT, _creationCode(1));
    }

    /// @notice CREATE3 地址 = f(creator, salt)。无参 getDeployed 把 address(this) 当作 creator。
    ///         所以从 factory 预测 和 显式传入 factory 相同;从本测试合约预测则会得到另一个地址。
    function test_GetDeployed_UsesFactoryAsCreator() public {
        // factory.getDeployed(salt) → CREATE3.getDeployed(salt, address(this)=factory)
        address fromFactory = factory.getDeployed(SALT);
        // 库的两参数版本:手动指定 creator=factory,应与上一行相同
        address fromLib = CREATE3.getDeployed(SALT, address(factory));
        // 在本测试合约里调无参版本:creator=Create3FactoryTest,地址必不同
        address fromThisTest = CREATE3.getDeployed(SALT);

        assertEq(fromFactory, fromLib);
        assertTrue(fromFactory != fromThisTest);
    }

    function testFuzz_DeployCounter_ConstructorArg(bytes32 salt, uint256 initialNumber) public {
        Counter counter = _deployCounter(salt, initialNumber);

        assertEq(address(counter), factory.getDeployed(salt));
        assertEq(counter.number(), initialNumber);
    }
}
