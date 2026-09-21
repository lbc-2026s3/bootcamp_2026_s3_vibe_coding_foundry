// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {VestingWallet} from "openzeppelin-contracts/contracts/finance/VestingWallet.sol";

/// @notice TokenVesting:基于 OpenZeppelin VestingWallet,部署后立即开始计时:
///         12 个月 Cliff(不解锁),之后 24 个月线性释放,从第 13 个月起每月解锁 1/24。
///         release() 将当前已解锁的 ERC20 发送给受益人。
contract TokenVesting is VestingWallet {
    /// @notice Cliff 时长:12 个月(每月按 30 天计)
    uint64 public constant CLIFF_DURATION = 12 * 30 days;
    /// @notice 线性释放时长:24 个月(每月按 30 天计)
    uint64 public constant VESTING_DURATION = 24 * 30 days;

    /// @notice 锁定的 ERC20
    IERC20 public immutable token;

    /// @param token_ 锁定的 ERC20 地址
    /// @param beneficiary_ 受益人
    /// @dev start = 部署时刻(block.timestamp),总 duration = Cliff + 线性释放 = 36 个月
    constructor(address token_, address beneficiary_)
        VestingWallet(beneficiary_, uint64(block.timestamp), CLIFF_DURATION + VESTING_DURATION)
    {
        require(token_ != address(0), "Invalid token");
        token = IERC20(token_);
    }

    /// @notice 释放当前已解锁的 ERC20 给受益人。
    /// @dev OZ 原版无参 release() 释放的是原生 ETH,这里 override 为释放本合约锁定的 ERC20。
    function release() public virtual override {
        // release 函数内部会进行转账 safeTransfer 操作，所以这里直接调用即可
        release(address(token));
    }

    /// @dev 解锁曲线:Cliff 内为 0;Cliff 结束后 24 个月内按秒线性递增,第 N 个月末解锁 (N-12)/24。
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view virtual override returns (uint256) {
        uint256 cliffEnd = start() + CLIFF_DURATION;
        if (timestamp < cliffEnd) {
            return 0;
        }
        uint256 elapsed = timestamp - cliffEnd;
        if (elapsed >= VESTING_DURATION) {
            return totalAllocation;
        }
        return (totalAllocation * elapsed) / VESTING_DURATION;
    }
}
