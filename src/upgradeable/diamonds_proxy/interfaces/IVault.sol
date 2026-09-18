// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IVault {
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 fee);

    error ZeroAmount();
    error InsufficientBalance();
    error TransferFailed();

    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function balanceOf(address user) external view returns (uint256);

    function totalDeposits() external view returns (uint256);
}
