// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title DAOBank — DAO 金库
/// @notice 任何人可存入 ETH；仅 owner（通常为 `TimelockController`，由 `DAOGov` 排队执行）可提取资金。
/// @dev 存款记账用于透明度；资金归属金库，由治理提案经 Timelock 延迟后决定如何 withdraw。
contract DAOBank is Ownable, ReentrancyGuard {
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error TransferFailed();

    /// @notice 每个地址累计存入金额（不含提取冲减；金库由 owner 统一调度）
    mapping(address => uint256) public deposits;

    event Deposited(address indexed depositor, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    /// @param initialOwner 管理员；部署后应设为 `TimelockController`（由 `DAOGov` 提案驱动）
    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
    }

    /// @notice 显式存款
    function deposit() external payable {
        _deposit(msg.sender);
    }

    /// @notice 直接转 ETH 也会记入存款
    receive() external payable {
        _deposit(msg.sender);
    }

    /// @notice 仅 owner 可提取任意金额到指定地址
    /// @param to 收款地址
    /// @param amount 提取的 wei 数量
    function withdraw(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientBalance();

        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(to, amount);
    }

    function _deposit(address depositor) internal {
        if (msg.value == 0) revert ZeroAmount();
        deposits[depositor] += msg.value;
        emit Deposited(depositor, msg.value);
    }
}
