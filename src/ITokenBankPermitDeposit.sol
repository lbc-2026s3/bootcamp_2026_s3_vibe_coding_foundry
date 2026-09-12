// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice TokenBank ERC-2612 扩展存款接口,供 ERC-165 探测
interface ITokenBankPermitDeposit {
    function permitDeposit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}
