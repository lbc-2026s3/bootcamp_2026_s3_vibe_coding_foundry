// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {KKToken} from "./KKToken.sol";

/// @notice 单池 ETH 质押挖矿，奖励记账方式参考 SushiSwap MasterChef。
/// @dev 每个区块铸造 10 KK，按用户质押的 ETH 数量占总量的比例分配。
///      无人质押的区块不铸造。用户交互时一次性结算中间经过的区块（懒更新）。
contract StakingPool is ReentrancyGuard {
    /// @dev MasterChef 用 1e12 放大 accPerShare，避免按份额除法时精度丢失。
    // acc: accumulated 累计
    uint256 public constant ACC_PRECISION = 1e12;
    /// @notice 每个区块产出的 KK（18 位小数）
    uint256 public constant REWARD_PER_BLOCK = 10e18;

    KKToken public immutable kkToken;

    /// @notice 每 1 wei ETH 累计可分到的 KK，已乘 ACC_PRECISION
    uint256 public accRewardPerShare;
    /// @notice 奖励已结算到的区块
    uint256 public lastRewardBlock;
    /// @notice 当前质押的 ETH 总量
    uint256 public totalStaked;

    struct UserInfo {
        /// @notice 该用户当前质押的 ETH 数量
        uint256 amount;
        /// @dev 用户已结算进 rewardDebt 的奖励，避免重复领取
        uint256 rewardDebt;
    }

    mapping(address user => UserInfo) public userInfo;

    error ZeroAmount();
    error InsufficientStake();
    error EthTransferFailed();

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);

    constructor() {
        kkToken = new KKToken(address(this));
        lastRewardBlock = block.number;
    }

    /// @notice 把 [lastRewardBlock, block.number) 的产出记入 accRewardPerShare，并铸造 KK 到本合约。
    function updatePool() public {
        if (block.number <= lastRewardBlock) return;

        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocks = block.number - lastRewardBlock;
        uint256 reward = blocks * REWARD_PER_BLOCK;
        kkToken.mint(address(this), reward);
        accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;
        lastRewardBlock = block.number;
    }

    /// @notice 用户当前可领取、尚未入账的 KK
    function pendingReward(address user) external view returns (uint256) {
        UserInfo storage info = userInfo[user];
        uint256 acc = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked != 0) {
            uint256 reward = (block.number - lastRewardBlock) * REWARD_PER_BLOCK;
            acc += (reward * ACC_PRECISION) / totalStaked;
        }
        return (info.amount * acc) / ACC_PRECISION - info.rewardDebt;
    }

    /// @notice 质押 ETH。若已有仓位，先结算已产生的 KK。
    function stake() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();

        updatePool();
        UserInfo storage info = userInfo[msg.sender];
        _harvest(info, msg.sender);

        info.amount += msg.value;
        totalStaked += msg.value;
        info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

        emit Staked(msg.sender, msg.value);
    }

    /// @notice 提取质押的 ETH 本金，并结算对应 KK。剩余仓位继续挖矿。
    function withdraw(uint256 amount) external nonReentrant {
        UserInfo storage info = userInfo[msg.sender];
        if (amount == 0) revert ZeroAmount();
        if (amount > info.amount) revert InsufficientStake();

        updatePool();
        _harvest(info, msg.sender);

        info.amount -= amount;
        totalStaked -= amount;
        info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;

        emit Withdrawn(msg.sender, amount);

        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert EthTransferFailed();
    }

    /// @notice 只领取 KK，不取出 ETH。
    function claim() external nonReentrant {
        updatePool();
        UserInfo storage info = userInfo[msg.sender];
        _harvest(info, msg.sender);
        info.rewardDebt = (info.amount * accRewardPerShare) / ACC_PRECISION;
    }

    function _harvest(UserInfo storage info, address user) internal {
        if (info.amount == 0) return;
        uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;
        if (pending == 0) return;

        uint256 balance = kkToken.balanceOf(address(this));
        if (pending > balance) pending = balance;
        kkToken.transfer(user, pending);
        emit Claimed(user, pending);
    }
}
