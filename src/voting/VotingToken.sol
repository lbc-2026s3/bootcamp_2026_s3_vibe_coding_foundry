// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Nonces} from "openzeppelin-contracts/contracts/utils/Nonces.sol";

/// @title VotingToken — 基于 OpenZeppelin 的可投票 ERC20
/// @notice 标准治理代币：持有量通过 `delegate` 激活为投票权，可与 Governor 组合使用。
/// @dev 关键：余额默认不算票；必须 `delegate(self)` 或委托给他人后，被委托者 `getVotes` 才会增加。
///      Checkpoint 按 `block.number` 记录，可用 `getPastVotes` / `getPastTotalSupply` 查历史票权。
contract VotingToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    error ZeroAddress();
    error ZeroAmount();

    event Minted(address indexed to, uint256 amount);

    /// @param name_ Token 名称（同时用于 EIP-712 domain）
    /// @param symbol_ Token 符号
    /// @param initialOwner 可调用 `mint` 的地址
    /// @param initialSupply 部署时铸给 `initialOwner` 的数量（可为 0）
    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner,
        uint256 initialSupply
    ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        if (initialSupply > 0) {
            _mint(initialOwner, initialSupply);
        }
    }

    /// @notice 仅 owner 可增发
    /// @dev 票权跟「接收方当前的委托目标」走，不是每次 mint 都要重新 delegate：
    ///      - 若 `to` 从未 delegate → mint 后余额增加，但 getVotes(to) 仍为 0
    ///      - 若 `to` 已自委托（例：有 100 币且 delegate(自己) → 100 票），再 mint 50
    ///        → 余额 150，票数也自动变成 150（无需再调 delegate）
    ///      - 若 `to` 已委托给 Alice → 新增 50 票加到 Alice，不是 to
    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _mint(to, amount);
        emit Minted(to, amount);
    }

    /// @dev 必须显式 override：本合约同时继承 `ERC20` 与 `ERC20Votes`，两者都声明了 `_update`，
    ///      Solidity 要求子合约写出 `override(ERC20, ERC20Votes)` 消歧。
    ///
    ///      `super._update(...)` 不是「只调 ERC20」：按 C3 线性化会先进入 `ERC20Votes._update`
    ///      （校验供给上限 + `_transferVotingUnits` 同步票权 checkpoint），再由其 `super` 调到
    ///      `ERC20._update`（真正改余额）。
    ///
    ///      若写成 `ERC20._update(from, to, value)`，会跳过 Votes 逻辑，转账/铸造后票权不同步。
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /// @dev ERC20Permit 与 Votes/Nonces 共享 nonce 存储，需显式 resolve override
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
