// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DeFiVault
/// @notice 一种 ERC1155 同时作为可质押资产、质押凭证和奖励。
/// 用户质押 LP 或治理代币并锁定一段时间，按锁定档位获得奖励。
/// 到期后取回原来的代币，并领走尚未领取的奖励。
contract DeFiVault is ERC1155, Ownable, ReentrancyGuard, ERC1155Holder {
    uint256 public constant LP_TOKEN = 1;
    uint256 public constant REWARD_TOKEN = 2;
    uint256 public constant GOVERNANCE_TOKEN = 3;
    uint256 public constant STAKING_TOKEN = 4;

    uint256 public constant MIN_DURATION = 30 days;
    uint256 public constant YEAR = 365 days;

    struct StakingInfo {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        uint256 rewardRate;
        bool active;
    }

    mapping(address user => StakingInfo) public stakingInfo;
    mapping(address user => uint256) public totalRewards;
    mapping(address user => uint256) public lastClaimTime;
    mapping(address user => uint256[]) private _stakedTokenIds;
    mapping(address user => uint256[]) private _stakedAmounts;

    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;

    event TokensMinted(address indexed to, uint256 indexed id, uint256 amount);
    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 amount);

    /// @notice 部署者可以铸造 LP 和治理代币。奖励和质押凭证只能由金库自己铸造。
    constructor() ERC1155("https://example.com/vault/{id}.json") Ownable(msg.sender) {}

    /// @inheritdoc ERC1155
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @notice LP 和治理代币可以质押。奖励和质押凭证不行。
    function isStakeable(uint256 id) public pure returns (bool) {
        return id == LP_TOKEN || id == GOVERNANCE_TOKEN;
    }

    /// @notice 锁定时长对应的年化百分比。30 天 8%，90 天 10%，180 天 12%，365 天 15%。
    function rewardRateFor(uint256 duration) public pure returns (uint256) {
        if (duration >= YEAR) return 15;
        if (duration >= 180 days) return 12;
        if (duration >= 90 days) return 10;
        return 8;
    }

    /// @notice 当前仓位里质押的代币 id 和数量。
    function stakedTokens(address user) external view returns (uint256[] memory tokenIds, uint256[] memory amounts) {
        return (_stakedTokenIds[user], _stakedAmounts[user]);
    }

    /// @notice 给地址铸造可质押资产。不能铸造奖励或质押凭证。
    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        require(to != address(0), "Zero address");
        require(amount != 0, "Zero amount");
        require(isStakeable(id), "Not mintable");
        _mint(to, id, amount, "");
        emit TokensMinted(to, id, amount);
    }

    /// @notice 把 LP 和/或治理代币锁进金库。同一地址同时只能有一个仓位。
    /// 锁定期内铸造等量质押凭证；到期后 unstake 会烧掉凭证并退回本金。
    function stake(uint256[] memory tokenIds, uint256[] memory amounts, uint256 duration) external nonReentrant {
        require(tokenIds.length == amounts.length, "Arrays length mismatch");
        require(tokenIds.length != 0, "Empty stake");
        require(duration >= MIN_DURATION, "Minimum staking period is 30 days");
        require(!stakingInfo[msg.sender].active, "Already staking");

        uint256 totalAmount = _validateStake(tokenIds, amounts);

        stakingInfo[msg.sender] = StakingInfo({
            amount: totalAmount,
            startTime: block.timestamp,
            duration: duration,
            rewardRate: rewardRateFor(duration),
            active: true
        });
        lastClaimTime[msg.sender] = block.timestamp;
        _stakedTokenIds[msg.sender] = tokenIds;
        _stakedAmounts[msg.sender] = amounts;
        totalStaked += totalAmount;

        _safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, "");
        _mint(msg.sender, STAKING_TOKEN, totalAmount, "");
        emit Staked(msg.sender, totalAmount, duration);
    }

    /// @notice 锁定期结束后取回本金，并领取自上次领取以来的奖励。
    function unstake() external nonReentrant {
        StakingInfo memory info = stakingInfo[msg.sender];
        require(info.active, "No active staking");
        require(block.timestamp >= info.startTime + info.duration, "Staking period not ended");

        uint256 rewards = _pendingRewards(msg.sender);
        uint256[] memory tokenIds = _stakedTokenIds[msg.sender];
        uint256[] memory amounts = _stakedAmounts[msg.sender];

        delete stakingInfo[msg.sender];
        delete _stakedTokenIds[msg.sender];
        delete _stakedAmounts[msg.sender];
        totalStaked -= info.amount;
        if (rewards != 0) {
            lastClaimTime[msg.sender] = block.timestamp;
            totalRewards[msg.sender] += rewards;
            totalRewardsDistributed += rewards;
        }

        _burn(msg.sender, STAKING_TOKEN, info.amount);
        _safeBatchTransferFrom(address(this), msg.sender, tokenIds, amounts, "");
        if (rewards != 0) {
            _mint(msg.sender, REWARD_TOKEN, rewards, "");
        }
        emit Unstaked(msg.sender, info.amount, rewards);
    }

    /// @notice 领取当前仓位已经产生、尚未入账的奖励。仓位继续锁定。
    function claimRewards() external nonReentrant {
        require(stakingInfo[msg.sender].active, "No active staking");
        uint256 rewards = _pendingRewards(msg.sender);
        require(rewards != 0, "No rewards to claim");

        lastClaimTime[msg.sender] = block.timestamp;
        totalRewards[msg.sender] += rewards;
        totalRewardsDistributed += rewards;

        _mint(msg.sender, REWARD_TOKEN, rewards, "");
        emit RewardsClaimed(msg.sender, rewards);
    }

    /// @notice 尚未领取的奖励。按上次领取到现在的时间计算，不会把已领部分再算一遍。
    function getPendingRewards(address user) external view returns (uint256) {
        return _pendingRewards(user);
    }

    function _validateStake(uint256[] memory tokenIds, uint256[] memory amounts)
        internal
        pure
        returns (uint256 totalAmount)
    {
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            require(amounts[i] != 0, "Zero amount");
            require(isStakeable(tokenIds[i]), "Token not stakeable");
            for (uint256 j = 0; j < i; ++j) {
                require(tokenIds[j] != tokenIds[i], "Duplicate token id");
            }
            totalAmount += amounts[i];
        }
    }

    /// @dev 年化奖励 = 本金 * 百分比 * 经过时间 / 一年。先乘后除。
    function _pendingRewards(address user) internal view returns (uint256) {
        StakingInfo memory info = stakingInfo[user];
        if (!info.active) return 0;

        uint256 fromTime = lastClaimTime[user];
        if (block.timestamp <= fromTime) return 0;

        uint256 elapsed = block.timestamp - fromTime;
        return (info.amount * info.rewardRate * elapsed) / (YEAR * 100);
    }
}
