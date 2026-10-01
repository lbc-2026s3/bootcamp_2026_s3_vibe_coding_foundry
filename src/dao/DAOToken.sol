// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VotingToken} from "../voting/VotingToken.sol";

/// @title DAOToken — DAO 治理代币
/// @notice 复用 `VotingToken`（ERC20 + Permit + Votes）；供 `DAOGov` 投票使用。
contract DAOToken is VotingToken {
    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner,
        uint256 initialSupply
    ) VotingToken(name_, symbol_, initialOwner, initialSupply) {}
}
