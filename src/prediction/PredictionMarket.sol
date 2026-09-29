// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {OutcomeToken} from "./OutcomeToken.sol";

/// @notice 二元预测市场：抵押品 split/merge 为 YES/NO 份额（本任务仅构造与 split/merge）。
contract PredictionMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    string public question;
    IERC20 public immutable collateral;
    uint256 public immutable deadline;
    address public immutable oracle;
    OutcomeToken public immutable yesToken;
    OutcomeToken public immutable noToken;

    bool public resolved;
    bool public yesWins;

    error ZeroAddress();
    error ZeroAmount();
    error InvalidDeadline();
    error MarketClosed();

    event Split(address indexed user, uint256 amount);
    event Merged(address indexed user, uint256 amount);

    /// @param question_ 市场问题
    /// @param collateral_ 抵押品 ERC20
    /// @param deadline_ 交易截止时间（须晚于部署时刻）
    /// @param oracle_ 裁定地址
    constructor(string memory question_, address collateral_, uint256 deadline_, address oracle_) {
        if (collateral_ == address(0) || oracle_ == address(0)) revert ZeroAddress();
        if (deadline_ <= block.timestamp) revert InvalidDeadline();

        question = question_;
        collateral = IERC20(collateral_);
        deadline = deadline_;
        oracle = oracle_;

        uint8 decimals_ = IERC20Metadata(collateral_).decimals();
        yesToken = new OutcomeToken("YES", "YES", decimals_, address(this));
        noToken = new OutcomeToken("NO", "NO", decimals_, address(this));
    }

    /// @notice 存入抵押品，铸造等量 YES + NO。
    function split(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!_tradingOpen()) revert MarketClosed();

        collateral.safeTransferFrom(msg.sender, address(this), amount);
        yesToken.mint(msg.sender, amount);
        noToken.mint(msg.sender, amount);

        emit Split(msg.sender, amount);
    }

    /// @notice 销毁等量 YES + NO，退回抵押品。
    function merge(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (!_tradingOpen()) revert MarketClosed();

        yesToken.burn(msg.sender, amount);
        noToken.burn(msg.sender, amount);
        collateral.safeTransfer(msg.sender, amount);

        emit Merged(msg.sender, amount);
    }

    function _tradingOpen() internal view returns (bool) {
        return !resolved && block.timestamp < deadline;
    }
}
