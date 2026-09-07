// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice TokenBankV2:存入指定 ERC20,记录每个用户存入的 token 数量,用户可自行提取,无管理员
/// @dev 使用 SafeERC20,兼容 USDT 等 transfer/transferFrom 不返回 bool 的非标准代币
contract TokenBankV2 {
    using SafeERC20 for IERC20;

    /// @notice 银行接受的 token
    IERC20 public immutable token;

    /// @notice 每个用户累计存入的 token 数量
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(IERC20 token_) {
        token = token_;
    }

    /// @notice 存入 token:调用前需先 approve 本合约
    function deposit(uint256 amount) external {
        require(amount > 0, "Zero deposit");
        token.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    /// @notice 用户提取自己存入的 token(部分或全部)
    function withdraw(uint256 amount) external {
        require(amount > 0, "Zero withdraw");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        // 先扣账再转账,防止重入
        balances[msg.sender] -= amount;
        token.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }
}
