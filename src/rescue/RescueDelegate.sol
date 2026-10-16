// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title RescueDelegate
/// @notice EIP-7702 委托实现。泄漏地址签一份授权，把代码临时指向本合约。
///         赞助地址发起交易并支付 gas。函数跑在泄漏地址的上下文里，`address(this)` 就是泄漏地址，
///         所以代币合约看到的 `msg.sender` 也是泄漏地址。资产只能转到构造时写死的 `safe`。
contract RescueDelegate {
    using SafeERC20 for IERC20;

    /// @notice 资产唯一接收地址。
    address public immutable safe;

    error SafeIsZero();
    error NotSafe();
    error NothingToRescue();

    /// @param safe_ 抢救后的收款地址，部署后不能改。
    constructor(address safe_) {
        if (safe_ == address(0)) revert SafeIsZero();
        safe = safe_;
    }

    /// @notice 把泄漏地址上的 ERC20 和列出的 NFT 转到 `safe`。
    /// @param token ERC20 合约。amount 为 0 时跳过。
    /// @param amount 原始单位。18 位小数的代币，100 个是 `100 * 10 ** decimals()`。
    /// @param nft ERC721 合约。
    /// @param tokenIds 要转走的 tokenId。某一枚失败则整笔交易回滚。
    function rescue(address token, uint256 amount, address nft, uint256[] calldata tokenIds) external {
        if (msg.sender != safe) revert NotSafe();
        if (amount == 0 && tokenIds.length == 0) revert NothingToRescue();

        if (amount > 0) {
            IERC20(token).safeTransfer(safe, amount);
        }

        uint256 n = tokenIds.length;
        for (uint256 i = 0; i < n; ++i) {
            IERC721(nft).safeTransferFrom(address(this), safe, tokenIds[i]);
        }
    }
}
