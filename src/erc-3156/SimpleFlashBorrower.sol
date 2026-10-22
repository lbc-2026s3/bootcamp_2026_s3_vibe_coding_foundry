// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";

/// @notice 向指定的 ERC-3156 lender 借一笔同种代币，回调里记账并授权还款。
/// @dev 手续费必须事先放在本合约里。`flashLoan` 只铸造本金，不铸造手续费。
contract SimpleFlashBorrower is IERC3156FlashBorrower {
    bytes32 private constant _RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");

    IERC3156FlashLender public immutable lender;

    /// @notice 成功进入回调的次数。整笔交易回滚时不会留下这次增加。
    uint256 public borrowCount;
    /// @notice 回调当时本合约余额：事先放入的手续费 + 刚铸出的本金。
    uint256 public balanceDuringLoan;
    /// @notice 回调当时的总供应：贷款前的供应 + 临时本金。返回后本金会被烧掉。
    uint256 public supplyDuringLoan;

    error ZeroAddress();
    error NotLender(address caller);
    error UnexpectedToken(address token);
    error NotSelfInitiated(address initiator);

    event FlashBorrowed(address indexed initiator, uint256 amount, uint256 fee, uint256 balanceDuringLoan);

    constructor(IERC3156FlashLender lender_) {
        if (address(lender_) == address(0)) revert ZeroAddress();
        lender = lender_;
    }

    /// @notice 借入 `amount` 个 `lender` 代币。谁都可以调用，手续费从本合约余额扣。
    function flashBorrow(uint256 amount) external {
        lender.flashLoan(this, address(lender), amount, "");
    }

    /// @inheritdoc IERC3156FlashBorrower
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata)
        external
        returns (bytes32)
    {
        if (msg.sender != address(lender)) revert NotLender(msg.sender);
        if (token != address(lender)) revert UnexpectedToken(token);
        // 别人直接把本合约填进 flashLoan 的 receiver 时，initiator 不是自己，不能动这里的手续费余额。
        if (initiator != address(this)) revert NotSelfInitiated(initiator);

        balanceDuringLoan = IERC20(token).balanceOf(address(this));
        supplyDuringLoan = IERC20(token).totalSupply();
        borrowCount += 1;

        // 这里已经持有临时本金。套利插在批准还款之前：
        // 到贵的市场卖掉 FMT，再到便宜的市场买回至少 amount + fee。
        // 多出来的另一种资产就是利润。买不够则还不上，整笔交易回滚。
        // OpenZeppelin 在回调返回后 spendAllowance，再烧掉本金、把手续费转给 feeReceiver。
        IERC20(token).approve(address(lender), amount + fee);

        emit FlashBorrowed(initiator, amount, fee, balanceDuringLoan);
        return _RETURN_VALUE;
    }
}
