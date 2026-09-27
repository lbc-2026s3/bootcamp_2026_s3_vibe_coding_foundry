// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title RebaseToken — 每年通缩 1% 的 rebase 型 ERC20
/// @notice 持仓用「份额」记账；`rebase` 只下调总供给，份额不变，
///         于是 `balanceOf` 自动反映通缩后的余额（按份额占比缩放）。
/// @dev 初始发行量 100 万枚（18 位小数）。任何人在满一年后可调用 `rebase`；
///      若多年未 rebase，一次可追上全部到期年份。
contract RebaseToken is ERC20 {
    /// @notice 一年（按 365 天）
    uint256 public constant YEAR = 365 days;

    /// @notice 每年通缩比例：1% = 100 bps
    uint256 public constant DEFLATION_BPS = 100;

    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice 初始发行量：100 万枚
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;

    /// @dev 用户持有的份额（蛋糕怎么切）；转账改份额，rebase 不改。
    mapping(address account => uint256) private _shares;

    /// @dev 全网份额总数（蛋糕块数之和）。转账只是搬家，总数通常不变；burn 才会减少。
    uint256 private _totalShares;

    /// @dev 当前代币总发行量（蛋糕有多大），即 `totalSupply()`。
    ///      rebase 每年把这块蛋糕缩小 1%；份额不变，所以每人 `balanceOf` 同比变小。
    uint256 private _tokenSupply;

    /// @notice 上一轮 rebase 生效的时间戳（用于计算已过完整年数）
    uint256 public lastRebaseTimestamp;

    /// @notice 累计已执行的 rebase 年数
    uint256 public rebaseCount;

    error RebaseTooEarly(uint256 nextRebaseTimestamp);
    error ZeroAddress();
    error MintDisabled();
    /// @notice 转账金额过小，折算份额后收款人得不到有效余额
    error TransferTooSmall(uint256 value);

    event Rebase(uint256 yearsApplied, uint256 previousSupply, uint256 newSupply);

    constructor(address recipient) ERC20("Rebase Token", "RBT") {
        if (recipient == address(0)) revert ZeroAddress();

        _tokenSupply = INITIAL_SUPPLY;
        _totalShares = INITIAL_SUPPLY;
        _shares[recipient] = INITIAL_SUPPLY;
        lastRebaseTimestamp = block.timestamp;

        emit Transfer(address(0), recipient, INITIAL_SUPPLY);
    }

    /// @inheritdoc ERC20
    function totalSupply() public view override returns (uint256) {
        return _tokenSupply;
    }

    /// @inheritdoc ERC20
    /// @dev `balance = shares * tokenSupply / totalShares`，rebase 后随供给下降。
    function balanceOf(address account) public view override returns (uint256) {
        if (_totalShares == 0) return 0;
        return (_shares[account] * _tokenSupply) / _totalShares;
    }

    /// @notice 当前账户持有的份额（rebase 不改变份额）
    function sharesOf(address account) external view returns (uint256) {
        return _shares[account];
    }

    /// @notice 全网份额总量
    function totalShares() external view returns (uint256) {
        return _totalShares;
    }

    /// @notice 下一次允许 rebase 的时间戳
    function nextRebaseTimestamp() public view returns (uint256) {
        return lastRebaseTimestamp + YEAR;
    }

    /// @notice 当前已到期、可一次性追上的完整年数
    function pendingRebaseYears() public view returns (uint256) {
        if (block.timestamp < nextRebaseTimestamp()) return 0;
        return (block.timestamp - lastRebaseTimestamp) / YEAR;
    }

    /// @notice 执行通缩 rebase：发行量 = 上一年 × 99%
    /// @return yearsApplied 本次追上的年数
    /// @return newSupply rebase 后的总供给
    function rebase() external returns (uint256 yearsApplied, uint256 newSupply) {
        yearsApplied = pendingRebaseYears();
        if (yearsApplied == 0) revert RebaseTooEarly(nextRebaseTimestamp());

        uint256 previousSupply = _tokenSupply;
        newSupply = previousSupply;

        for (uint256 i = 0; i < yearsApplied; ++i) {
            newSupply = (newSupply * (BPS_DENOMINATOR - DEFLATION_BPS)) / BPS_DENOMINATOR;
        }

        // 极端多年通缩后供给可能被整除为 0；至少保留 1 wei，避免后续转账除零
        if (newSupply == 0) newSupply = 1;

        _tokenSupply = newSupply;
        lastRebaseTimestamp += yearsApplied * YEAR;
        rebaseCount += yearsApplied;

        emit Rebase(yearsApplied, previousSupply, newSupply);
    }

    /// @dev 用份额记账覆盖 OZ 的余额更新；不触碰父合约私有 `_balances` / `_totalSupply`。
    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0)) revert MintDisabled();

        uint256 fromBalance = balanceOf(from);
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(from, fromBalance, value);
        }

        // 转出全部余额时带走全部份额，避免舍入粉尘
        uint256 shareAmount =
            value == fromBalance ? _shares[from] : (value * _totalShares) / _tokenSupply;

        if (shareAmount == 0) revert TransferTooSmall(value);

        // rebase 后 tokenSupply < totalShares 时，极小金额可能分到份额但 balanceOf 仍为 0
        if (to != address(0)) {
            uint256 credited = (shareAmount * _tokenSupply) / _totalShares;
            if (credited == 0) revert TransferTooSmall(value);
        }

        unchecked {
            _shares[from] -= shareAmount;
        }

        if (to == address(0)) {
            _totalShares -= shareAmount;
            _tokenSupply -= value;
        } else {
            _shares[to] += shareAmount;
        }

        emit Transfer(from, to, value);
    }
}
