// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IVaultV2 {
    function withdrawFeeBps() external view returns (uint256);

    function protocolFees() external view returns (uint256);
}
