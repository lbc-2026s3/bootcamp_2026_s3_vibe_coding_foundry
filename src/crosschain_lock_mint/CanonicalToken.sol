// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title CanonicalToken — lock-and-mint demo 的源链「原币」
/// @notice 部署时一次性铸造 1_000_000 枚给部署者，之后不可增发。
/// @dev 18 decimals。本 token 只作为金库锁仓对象，不承担跨链逻辑。
contract CanonicalToken is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    constructor() ERC20("Canonical Token", "CANON") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
