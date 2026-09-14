// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdConstants} from "forge-std/StdConstants.sol";
import {Counter} from "../src/Counter.sol";

contract CounterCreate2Test is Test {
    bytes32 internal constant SALT = keccak256("lbc-2026s3:Counter");

    function _initCode(uint256 initialNumber) private pure returns (bytes memory) {
        return abi.encodePacked(type(Counter).creationCode, abi.encode(initialNumber));
    }

    /// @dev 无 deployer 参数的 computeCreate2Address 默认 factory=0x4e59…。
    ///      单测里 `new C{salt:}` 的 sender 是本测试合约,脚本 --broadcast 才会走 factory。
    function _predictFrom(address deployer, bytes32 salt, uint256 initialNumber) private pure returns (address) {
        return vm.computeCreate2Address(salt, keccak256(_initCode(initialNumber)), deployer);
    }

    function test_Create2_MatchesPredictedAddress() public {
        address predicted = _predictFrom(address(this), SALT, 0);
        Counter counter = new Counter{salt: SALT}(0);

        assertEq(address(counter), predicted);
        assertEq(counter.number(), 0);
    }

    function test_Create2_FactoryAddress_DiffersFromTestContract() public view {
        address viaFactory = _predictFrom(StdConstants.CREATE2_FACTORY, SALT, 0);
        address viaThis = _predictFrom(address(this), SALT, 0);
        assertTrue(viaFactory != viaThis);
    }

    function test_Create2_DifferentConstructorArgs_DifferentAddress() public pure {
        assertTrue(
            _predictFrom(StdConstants.CREATE2_FACTORY, SALT, 0) != _predictFrom(StdConstants.CREATE2_FACTORY, SALT, 42)
        );
    }

    function test_Create2_DifferentSalt_DifferentAddress() public {
        Counter a = new Counter{salt: keccak256("salt-a")}(0);
        Counter b = new Counter{salt: keccak256("salt-b")}(0);
        assertTrue(address(a) != address(b));
    }

    function test_RevertWhen_SameSaltAndInitcodeTwice() public {
        new Counter{salt: SALT}(0);
        vm.expectRevert();
        this.deployWithSalt(SALT, 0);
    }

    function deployWithSalt(bytes32 salt, uint256 initialNumber) external {
        new Counter{salt: salt}(initialNumber);
    }
}
