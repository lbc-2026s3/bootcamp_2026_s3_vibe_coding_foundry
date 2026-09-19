// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Minimal copy of Chainlink AutomationCompatibleInterface (CLA → CRE migration still uses this shape).
/// @dev Source: smartcontractkit/chainlink contracts-v1.3.0
interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}
