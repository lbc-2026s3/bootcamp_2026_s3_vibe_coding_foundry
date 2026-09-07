// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC1363Receiver} from "openzeppelin-contracts/contracts/interfaces/IERC1363Receiver.sol";
import {IERC1363Spender} from "openzeppelin-contracts/contracts/interfaces/IERC1363Spender.sol";

import {TokenBankV2} from "./TokenBankV2.sol";

/// @notice TokenBankERC1363:继承 TokenBankV2,额外支持 ERC-1363 单笔存款
/// @dev 存款路径:
/// 1. ERC20: approve + deposit()(父合约,普通 transferFrom 不触发 1363 回调,无双重记账)
/// 2. transferAndCall / transferFromAndCall -> onTransferReceived
/// 3. approveAndCall -> onApprovalReceived(内部 transferFrom 拉款入账)
contract TokenBankERC1363 is TokenBankV2, IERC1363Receiver, IERC1363Spender {
    constructor(IERC20 token_) TokenBankV2(token_) {}

    /// @inheritdoc IERC1363Receiver
    function onTransferReceived(
        address, /* operator */
        address from,
        uint256 value,
        bytes calldata /* data */
    ) external override returns (bytes4) {
        require(msg.sender == address(token), "Invalid token");
        require(value > 0, "Zero deposit");
        require(from != address(0), "Zero from");

        balances[from] += value;
        emit Deposit(from, value);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    /// @inheritdoc IERC1363Spender
    function onApprovalReceived(address owner, uint256 value, bytes calldata /* data */ )
        external
        override
        returns (bytes4)
    {
        require(msg.sender == address(token), "Invalid token");
        require(value > 0, "Zero deposit");
        require(owner != address(0), "Zero owner");

        // 普通 transferFrom 不会再回调 onTransferReceived,只记一次账
        token.transferFrom(owner, address(this), value);
        balances[owner] += value;
        emit Deposit(owner, value);

        return IERC1363Spender.onApprovalReceived.selector;
    }
}
