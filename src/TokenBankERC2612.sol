// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import {ITokenBankPermitDeposit} from "./ITokenBankPermitDeposit.sol";
import {TokenBankV2} from "./TokenBankV2.sol";

/// @notice TokenBankERC2612:继承 TokenBankV2,额外支持 ERC-2612 permit 单笔存款
/// @dev 存款路径:
/// 1. ERC20: approve + deposit()(父合约)
/// 2. permitDeposit: 用户离线签 permit 后自行调用;合约内先 permit 再 transferFrom 入账(省掉单独 approve 交易)
/// @dev permit 签名可被他人抢先上链;用 try/catch 忽略重复 permit 失败,再靠已有 allowance 做 transferFrom(OZ 推荐)
/// @dev 通过 ERC-165 声明 ITokenBankPermitDeposit,便于前端/外部探测
contract TokenBankERC2612 is TokenBankV2, ERC165, ITokenBankPermitDeposit {
    using SafeERC20 for IERC20;

    constructor(IERC20 token_) TokenBankV2(token_) {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ITokenBankPermitDeposit).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice 通过 ERC-2612 permit 授权后存款,用户无需事先发 approve 交易
    /// @param amount 存入数量
    /// @param deadline permit 签名过期时间
    /// @param v 签名 v
    /// @param r 签名 r
    /// @param s 签名 s
    function permitDeposit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(amount > 0, "Zero deposit");

        // 先用签名给本合约授权。若有人已抢先提交同一笔 permit,这里会失败,但 allowance 已存在,下面 transferFrom 仍能成功。
        try IERC20Permit(address(token)).permit(msg.sender, address(this), amount, deadline, v, r, s) {} catch {}

        token.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
}
