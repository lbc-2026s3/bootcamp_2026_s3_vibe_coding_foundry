// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {OutcomeToken} from "./OutcomeToken.sol";

/// @notice 二元预测市场：抵押品 split/merge + CPAMM 流动性。
contract PredictionMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BPS = 30;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    string public question;
    IERC20 public immutable collateral;
    uint256 public immutable deadline;
    address public immutable oracle;
    OutcomeToken public immutable yesToken;
    OutcomeToken public immutable noToken;

    bool public resolved;
    bool public yesWins;

    uint256 public yesReserve;
    uint256 public noReserve;
    uint256 public totalLp;
    mapping(address => uint256) public lpBalances;

    error ZeroAddress();
    error ZeroAmount();
    error InvalidDeadline();
    error MarketClosed();
    error Slippage();
    error InsufficientLiquidity();
    error InvalidLiquidityRatio();

    event Split(address indexed user, uint256 amount);
    event Merged(address indexed user, uint256 amount);
    event LiquidityAdded(address indexed provider, uint256 yesAmount, uint256 noAmount, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 yesAmount, uint256 noAmount, uint256 lpBurned);

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

    /// @notice 存入 YES/NO，铸造 LP（首次任意比例；其后按储备比例）。
    function addLiquidity(uint256 yesAmount, uint256 noAmount, uint256 minLp)
        external
        nonReentrant
        returns (uint256 lpMinted)
    {
        if (yesAmount == 0 || noAmount == 0) revert ZeroAmount();
        if (!_tradingOpen()) revert MarketClosed();

        IERC20(address(yesToken)).safeTransferFrom(msg.sender, address(this), yesAmount);
        IERC20(address(noToken)).safeTransferFrom(msg.sender, address(this), noAmount);

        if (totalLp == 0) {
            uint256 liquidity = Math.sqrt(yesAmount * noAmount);
            if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
            lpBalances[address(1)] = MINIMUM_LIQUIDITY;
            lpMinted = liquidity - MINIMUM_LIQUIDITY;
            totalLp = liquidity;
        } else {
            uint256 lpFromYes = (yesAmount * totalLp) / yesReserve;
            uint256 lpFromNo = (noAmount * totalLp) / noReserve;
            lpMinted = lpFromYes < lpFromNo ? lpFromYes : lpFromNo;
            if (lpMinted == 0) revert InvalidLiquidityRatio();
            totalLp += lpMinted;
        }

        if (lpMinted < minLp) revert Slippage();

        lpBalances[msg.sender] += lpMinted;
        yesReserve += yesAmount;
        noReserve += noAmount;

        emit LiquidityAdded(msg.sender, yesAmount, noAmount, lpMinted);
    }

    /// @notice 销毁 LP，按比例取回 YES/NO（Open 或 Resolved；TradingClosed 禁止）。
    function removeLiquidity(uint256 lpAmount, uint256 minYes, uint256 minNo)
        external
        nonReentrant
        returns (uint256 yesOut, uint256 noOut)
    {
        if (lpAmount == 0) revert ZeroAmount();
        if (!_liquidityActionAllowed()) revert MarketClosed();
        if (lpBalances[msg.sender] < lpAmount) revert InsufficientLiquidity();

        yesOut = (lpAmount * yesReserve) / totalLp;
        noOut = (lpAmount * noReserve) / totalLp;
        if (yesOut < minYes || noOut < minNo) revert Slippage();

        lpBalances[msg.sender] -= lpAmount;
        totalLp -= lpAmount;
        yesReserve -= yesOut;
        noReserve -= noOut;

        IERC20(address(yesToken)).safeTransfer(msg.sender, yesOut);
        IERC20(address(noToken)).safeTransfer(msg.sender, noOut);

        emit LiquidityRemoved(msg.sender, yesOut, noOut, lpAmount);
    }

    function _tradingOpen() internal view returns (bool) {
        return !resolved && block.timestamp < deadline;
    }

    /// @dev Open 或 Resolved；TradingClosed（!resolved && ts >= deadline）禁止。
    function _liquidityActionAllowed() internal view returns (bool) {
        return resolved || (!resolved && block.timestamp < deadline);
    }
}
