// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/// @notice 教学用可卸载 facet：Add 后再 Remove，证明 selector 可裁剪。
contract ExperimentalFacet {
    function ping() external pure returns (bytes32) {
        return keccak256("pong");
    }
}
