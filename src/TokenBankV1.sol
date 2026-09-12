// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @notice TokenBankV1:存入 MyTokenV1,记录每个用户存入的 token 数量,仅管理员可提取全部
contract TokenBankV1 {
    /// @notice 管理员,初始为部署者,可通过 transferAdmin 转移
    address public admin;

    /// @notice 银行接受的 token
    IERC20 public immutable token;

    /// @notice 每个用户累计存入的 token 数量
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed admin, uint256 amount);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    constructor(IERC20 token_) {
        admin = msg.sender;
        token = token_;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    /// @notice 存入 token:调用前需先 approve 本合约
    function deposit(uint256 amount) external {
        require(amount > 0, "Zero deposit");
        token.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    /// @notice 仅管理员可提取合约内全部 token
    function withdraw() external onlyAdmin {
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "Nothing to withdraw");
        token.transfer(admin, amount);
        emit Withdraw(admin, amount);
    }

    /// @notice 仅管理员可将权限转移给 newAdmin
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Zero address");
        address previousAdmin = admin;
        admin = newAdmin;
        emit AdminTransferred(previousAdmin, newAdmin);
    }
}
