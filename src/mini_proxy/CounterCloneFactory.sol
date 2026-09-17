// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {Counter} from "./Counter.sol";

/// @notice 用 OZ Clones（EIP-1167）部署多份 Counter 最小代理，逻辑只部署一份。
contract CounterCloneFactory {
    address public immutable implementation;

    event CounterCloned(address indexed proxy, uint256 initialNumber);

    constructor() {
        implementation = address(new Counter());
    }

    /// @notice 克隆一份 Counter 并初始化。
    function createCounter(uint256 initialNumber) external returns (address proxy) {
        proxy = Clones.clone(implementation);
        Counter(proxy).initialize(initialNumber);
        emit CounterCloned(proxy, initialNumber);
    }

    /// @notice CREATE2 确定性克隆，可用 `predictAddress` 预计算地址。
    function createCounterDeterministic(uint256 initialNumber, bytes32 salt)
        external
        returns (address proxy)
    {
        proxy = Clones.cloneDeterministic(implementation, salt);
        Counter(proxy).initialize(initialNumber);
        emit CounterCloned(proxy, initialNumber);
    }

    /// @notice 预测 `createCounterDeterministic` 将部署到的地址。
    function predictAddress(bytes32 salt) external view returns (address) {
        return Clones.predictDeterministicAddress(implementation, salt);
    }
}
