// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Minimal copy of Chainlink ILogAutomation + Log struct.
/// @dev Source: smartcontractkit/chainlink contracts-v1.3.0
struct Log {
    uint256 index;
    uint256 timestamp;
    bytes32 txHash;
    uint256 blockNumber;
    bytes32 blockHash;
    address source;
    bytes32[] topics;
    bytes data;
}

interface ILogAutomation {
    function checkLog(Log calldata log, bytes memory checkData)
        external
        returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}
