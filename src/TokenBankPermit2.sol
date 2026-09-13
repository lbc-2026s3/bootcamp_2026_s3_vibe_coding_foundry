// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ISignatureTransfer} from "./interfaces/ISignatureTransfer.sol";
import {TokenBankV2} from "./TokenBankV2.sol";

/// @notice TokenBankPermit2:继承 TokenBankV2,额外支持 Uniswap Permit2 签名授权存款
/// @dev 存款路径:
/// 1. ERC20: approve(bank) + deposit()(父合约)
/// 2. depositWithPermit2: 用户先一次性 approve(Permit2),再离线签 PermitTransferFrom,
///    调用本方法由 Permit2 把 token 拉入银行并记账(无需再 approve 本合约)
/// @dev 签名中的 spender 必须是本合约地址(Permit2 校验 msg.sender == spender)
contract TokenBankPermit2 is TokenBankV2 {
    /// @notice Uniswap Permit2 合约
    ISignatureTransfer public immutable permit2;

    /// @param token_ 银行接受的 ERC20
    /// @param permit2_ Permit2 地址(主网/L2 均为 0x000000000022D473030F116dDEE9F6B43aC78BA3)
    constructor(IERC20 token_, ISignatureTransfer permit2_) TokenBankV2(token_) {
        require(address(permit2_) != address(0), "Zero permit2");
        permit2 = permit2_;
    }

    /// @notice 通过 Uniswap Permit2 签名授权转账完成存款
    /// @dev 调用前用户需已对 Permit2 授权本银行 token(通常一次性 max approve)
    /// @param permit 用户签名的 PermitTransferFrom(含 token/amount/nonce/deadline)
    /// @param signature EIP-712 签名(支持 65 字节或 EIP-2098 紧凑签名)
    function depositWithPermit2(ISignatureTransfer.PermitTransferFrom calldata permit, bytes calldata signature)
        external
    {
        require(permit.permitted.token == address(token), "Invalid token");
        uint256 amount = permit.permitted.amount;
        require(amount > 0, "Zero deposit");

        // Permit2 校验签名后从 owner(msg.sender) 拉 token 到本合约;spender 签名域为本合约
        permit2.permitTransferFrom(
            permit,
            ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amount}),
            msg.sender,
            signature
        );

        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
}
