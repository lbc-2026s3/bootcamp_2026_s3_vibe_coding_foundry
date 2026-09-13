// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {CREATE3} from "solmate/utils/CREATE3.sol";

/// @notice Solmate CREATE3 的薄封装。库函数是 internal,必须由合约调用,EOA 无法直接 CREATE3。
/// @dev 最终地址只取决于 (本工厂地址, salt),与被部署合约的 initcode 无关。
contract Create3Factory {
    event Deployed(bytes32 indexed salt, address indexed deployed);

    /// @notice 用 CREATE3 部署任意 creationCode(含构造参数编码)
    function deploy(bytes32 salt, bytes memory creationCode) external payable returns (address deployed) {
        deployed = CREATE3.deploy(salt, creationCode, msg.value);
        emit Deployed(salt, deployed);
    }

    /// @notice 预测本工厂用给定 salt 将部署到的地址
    function getDeployed(bytes32 salt) external view returns (address) {
        return CREATE3.getDeployed(salt);
    }

    /// @notice 预测任意 CREATE3 工厂地址上,给定 salt 对应的部署地址
    function getDeployed(bytes32 salt, address creator) external pure returns (address) {
        return CREATE3.getDeployed(salt, creator);
    }
}
