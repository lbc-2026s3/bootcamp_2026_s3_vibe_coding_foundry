// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @notice 质押挖矿奖励代币。只有 StakingPool（minter）可以增发。
contract KKToken is ERC20 {
    address public immutable minter;

    error OnlyMinter();
    error ZeroMinter();

    constructor(address minter_) ERC20("KK Token", "KK") {
        if (minter_ == address(0)) revert ZeroMinter();
        minter = minter_;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != minter) revert OnlyMinter();
        _mint(to, amount);
    }
}
