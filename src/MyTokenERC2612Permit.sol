// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @notice MyTokenERC2612Permit:固定供应量 ERC-2612(Permit) token,部署时铸造 100 万枚给部署者
/// @dev 基于 OpenZeppelin ERC20Permit,支持离线 EIP-712 签名授权,无需单独发 approve 交易
contract MyTokenERC2612Permit is ERC20Permit {
    /// @notice 初始供应量:100 万枚(18 位小数)
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    constructor() ERC20("MyToken2612", "MT2612") ERC20Permit("MyToken2612") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
