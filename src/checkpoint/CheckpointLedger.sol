// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Checkpoints} from "openzeppelin-contracts/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

/// @title CheckpointLedger — OpenZeppelin Checkpoints 教学示例
/// @notice 用 `Checkpoints.Trace208` 按 `block.number` 记录账户余额与总供给历史，
///         支持查询「任意历史区块」的余额（与 `ERC20Votes` 同款数据结构）。
/// @dev Trace208: key = uint48(block.number), value = uint208(amount)。
///      - 同一区块内多次更新会覆盖该区块的 checkpoint（不新增条目）。
///      - key 必须非递减；切勿把用户任意输入当作 key。
contract CheckpointLedger {
    using Checkpoints for Checkpoints.Trace208;
    using SafeCast for uint256;

    /// @dev 每个地址一条 Trace：key = block.number，value = 该地址余额。
    ///      用 `balanceOfAt(account, blockNumber)` 可查「某区块结束时」该地址的余额。
    mapping(address account => Checkpoints.Trace208) private _balances;

    /// @dev 全局一条 Trace：key = block.number，value = 总发行量。
    ///      用 `totalSupplyAt(blockNumber)` 可查「某区块结束时」的总供给。
    Checkpoints.Trace208 private _totalSupply;

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance(address account, uint256 balance, uint256 needed);

    event Minted(address indexed to, uint256 amount, uint256 newBalance);
    event Burned(address indexed from, uint256 amount, uint256 newBalance);
    event Transferred(address indexed from, address indexed to, uint256 amount);

    /// @notice 铸造并写入当前区块的余额 / 总供给 checkpoint
    function mint(address to, uint256 amount) external {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 newBalance = balanceOf(to) + amount;
        _writeBalance(to, newBalance);
        _writeTotalSupply(totalSupply() + amount);

        emit Minted(to, amount, newBalance);
    }

    /// @notice 销毁并写入当前区块的余额 / 总供给 checkpoint
    function burn(address from, uint256 amount) external {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 balance = balanceOf(from);
        if (balance < amount) revert InsufficientBalance(from, balance, amount);

        uint256 newBalance = balance - amount;
        _writeBalance(from, newBalance);
        _writeTotalSupply(totalSupply() - amount);

        emit Burned(from, amount, newBalance);
    }

    /// @notice 转账：双方余额都在当前区块写 checkpoint
    function transfer(address to, uint256 amount) external {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        address from = msg.sender;
        uint256 fromBalance = balanceOf(from);
        if (fromBalance < amount) revert InsufficientBalance(from, fromBalance, amount);

        _writeBalance(from, fromBalance - amount);
        _writeBalance(to, balanceOf(to) + amount);

        emit Transferred(from, to, amount);
    }

    /// @notice 当前余额（最新 checkpoint）
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account].latest();
    }

    /// @notice 在 `blockNumber` 结束时的余额（≤ 该区块的最近一次 checkpoint）
    /// @dev `upperLookupRecent` = 二分查找（`_upperBinaryLookup`）；条目多时先把窗口收窄到偏近期再二分。
    function balanceOfAt(address account, uint256 blockNumber) public view returns (uint256) {
        return _balances[account].upperLookupRecent(blockNumber.toUint48());
    }

    /// @notice 当前总供给
    function totalSupply() public view returns (uint256) {
        return _totalSupply.latest();
    }

    /// @notice 在 `blockNumber` 结束时的总供给
    /// @dev 同 `balanceOfAt`：OZ 内部用二分查找取 ≤ key 的最近 value。
    function totalSupplyAt(uint256 blockNumber) public view returns (uint256) {
        return _totalSupply.upperLookupRecent(blockNumber.toUint48());
    }

    /// @notice 某账户已写入的 checkpoint 数量
    function numCheckpoints(address account) public view returns (uint256) {
        return _balances[account].length();
    }

    /// @notice 读取某账户第 `index` 个 checkpoint（0-based）
    function checkpointAt(address account, uint32 index)
        public
        view
        returns (uint48 key, uint208 value)
    {
        Checkpoints.Checkpoint208 memory ckpt = _balances[account].pos(index);
        return (ckpt._key, ckpt._value);
    }

    /// @notice 最新一条余额 checkpoint 的元信息
    function latestCheckpoint(address account)
        public
        view
        returns (bool exists, uint48 key, uint208 value)
    {
        return _balances[account].latestCheckpoint();
    }

    function _writeBalance(address account, uint256 newBalance) private {
        _balances[account].push(block.number.toUint48(), newBalance.toUint208());
    }

    function _writeTotalSupply(uint256 newSupply) private {
        _totalSupply.push(block.number.toUint48(), newSupply.toUint208());
    }
}
