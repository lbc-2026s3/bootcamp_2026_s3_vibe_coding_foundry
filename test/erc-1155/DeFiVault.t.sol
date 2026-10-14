// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {DeFiVault} from "../../src/erc-1155/DeFiVault.sol";

/// @dev 取出本金或收到奖励时再领一次。外层调用已经占着重入锁，内层应失败。
contract RewardReenter is IERC1155Receiver {
    DeFiVault internal vault;
    bool internal attack;

    constructor(DeFiVault vault_) {
        vault = vault_;
    }

    function stake(uint256[] calldata tokenIds, uint256[] calldata amounts, uint256 duration) external {
        vault.stake(tokenIds, amounts, duration);
    }

    function unstake() external {
        attack = true;
        vault.unstake();
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        if (attack) {
            attack = false;
            vault.claimRewards();
        }
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        returns (bytes4)
    {
        if (attack) {
            attack = false;
            vault.claimRewards();
        }
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

contract DeFiVaultTest is Test, IERC1155Errors {
    DeFiVault internal vault;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal lp;
    uint256 internal reward;
    uint256 internal governance;
    uint256 internal staking;

    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 amount);

    function setUp() public {
        vault = new DeFiVault();
        lp = vault.LP_TOKEN();
        reward = vault.REWARD_TOKEN();
        governance = vault.GOVERNANCE_TOKEN();
        staking = vault.STAKING_TOKEN();
    }

    function test_MetadataAndRates() public view {
        assertEq(vault.owner(), address(this));
        assertEq(vault.uri(lp), "https://example.com/vault/{id}.json");
        assertTrue(vault.isStakeable(lp));
        assertTrue(vault.isStakeable(governance));
        assertFalse(vault.isStakeable(reward));
        assertFalse(vault.isStakeable(staking));
        assertEq(vault.rewardRateFor(30 days), 8);
        assertEq(vault.rewardRateFor(89 days), 8);
        assertEq(vault.rewardRateFor(90 days), 10);
        assertEq(vault.rewardRateFor(180 days), 12);
        assertEq(vault.rewardRateFor(364 days), 12);
        assertEq(vault.rewardRateFor(365 days), 15);
    }

    function test_Mint_ByOwner() public {
        vault.mint(alice, lp, 1_000);
        vault.mint(alice, governance, 50);

        assertEq(vault.balanceOf(alice, lp), 1_000);
        assertEq(vault.balanceOf(alice, governance), 50);
    }

    function test_RevertWhen_NonOwnerMints(address caller) public {
        vm.assume(caller != address(this) && caller != address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        vault.mint(caller, lp, 1);
    }

    function test_RevertWhen_MintRewardOrStakingToken() public {
        vm.expectRevert(bytes("Not mintable"));
        vault.mint(alice, reward, 1);

        vm.expectRevert(bytes("Not mintable"));
        vault.mint(alice, staking, 1);
    }

    function test_Stake_LocksTokensAndMintsReceipt() public {
        _mintStakeable(alice, 1_000, 400);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = lp;
        ids[1] = governance;
        amounts[0] = 1_000;
        amounts[1] = 400;

        vm.expectEmit(true, false, false, true, address(vault));
        emit Staked(alice, 1_400, 90 days);

        vm.prank(alice);
        vault.stake(ids, amounts, 90 days);

        (uint256 amount, uint256 startTime, uint256 duration, uint256 rate, bool active) = vault.stakingInfo(alice);
        assertEq(amount, 1_400);
        assertEq(startTime, block.timestamp);
        assertEq(duration, 90 days);
        assertEq(rate, 10);
        assertTrue(active);
        assertEq(vault.totalStaked(), 1_400);
        assertEq(vault.balanceOf(alice, lp), 0);
        assertEq(vault.balanceOf(alice, governance), 0);
        assertEq(vault.balanceOf(address(vault), lp), 1_000);
        assertEq(vault.balanceOf(address(vault), governance), 400);
        assertEq(vault.balanceOf(alice, staking), 1_400);

        (uint256[] memory stakedIds, uint256[] memory stakedAmounts) = vault.stakedTokens(alice);
        assertEq(stakedIds.length, 2);
        assertEq(stakedIds[0], lp);
        assertEq(stakedIds[1], governance);
        assertEq(stakedAmounts[0], 1_000);
        assertEq(stakedAmounts[1], 400);
    }

    function test_RevertWhen_StakeInvalid() public {
        _mintStakeable(alice, 100, 100);

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = lp;
        amounts[0] = 100;

        vm.startPrank(alice);
        vm.expectRevert(bytes("Minimum staking period is 30 days"));
        vault.stake(ids, amounts, 30 days - 1);

        amounts[0] = 0;
        vm.expectRevert(bytes("Zero amount"));
        vault.stake(ids, amounts, 30 days);

        ids[0] = reward;
        amounts[0] = 1;
        vm.expectRevert(bytes("Token not stakeable"));
        vault.stake(ids, amounts, 30 days);

        uint256[] memory mismatch = new uint256[](2);
        vm.expectRevert(bytes("Arrays length mismatch"));
        vault.stake(ids, mismatch, 30 days);

        uint256[] memory emptyIds = new uint256[](0);
        uint256[] memory emptyAmounts = new uint256[](0);
        vm.expectRevert(bytes("Empty stake"));
        vault.stake(emptyIds, emptyAmounts, 30 days);

        uint256[] memory dupIds = new uint256[](2);
        uint256[] memory dupAmounts = new uint256[](2);
        dupIds[0] = lp;
        dupIds[1] = lp;
        dupAmounts[0] = 1;
        dupAmounts[1] = 1;
        vm.expectRevert(bytes("Duplicate token id"));
        vault.stake(dupIds, dupAmounts, 30 days);

        amounts[0] = 100;
        ids[0] = lp;
        vault.stake(ids, amounts, 30 days);
        vm.expectRevert(bytes("Already staking"));
        vault.stake(ids, amounts, 30 days);
        vm.stopPrank();
    }

    function test_RevertWhen_StakeExceedsBalance() public {
        vault.mint(alice, lp, 10);

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = lp;
        amounts[0] = 11;

        vm.expectRevert(abi.encodeWithSelector(ERC1155InsufficientBalance.selector, alice, 10, 11, lp));
        vm.prank(alice);
        vault.stake(ids, amounts, 30 days);
    }

    function test_Rewards_FullYearIsExactPercent() public {
        _stake(alice, 10_000, 365 days);

        vm.warp(block.timestamp + 365 days);
        assertEq(vault.getPendingRewards(alice), 1_500);

        vm.prank(alice);
        vault.claimRewards();

        assertEq(vault.balanceOf(alice, reward), 1_500);
        assertEq(vault.totalRewards(alice), 1_500);
        assertEq(vault.totalRewardsDistributed(), 1_500);
        assertEq(vault.getPendingRewards(alice), 0);
    }

    function test_Claim_DoesNotPayTwice() public {
        uint256 start = block.timestamp;
        _stake(alice, 10_000, 30 days);

        vm.warp(start + 30 days);
        uint256 first = _expectedReward(10_000, 8, 30 days);

        vm.expectEmit(true, false, false, true, address(vault));
        emit RewardsClaimed(alice, first);
        vm.prank(alice);
        vault.claimRewards();

        vm.expectRevert(bytes("No rewards to claim"));
        vm.prank(alice);
        vault.claimRewards();

        vm.warp(start + 60 days);
        uint256 second = _expectedReward(10_000, 8, 30 days);
        vm.prank(alice);
        vault.claimRewards();

        assertEq(vault.balanceOf(alice, reward), first + second);
        assertEq(vault.totalRewards(alice), first + second);
    }

    function test_Unstake_ReturnsPrincipalAndRemainder() public {
        uint256 start = block.timestamp;
        _stakeBoth(alice, 1_000, 250, 30 days);

        vm.warp(start + 30 days);
        uint256 claimed = _expectedReward(1_250, 8, 30 days);
        vm.prank(alice);
        vault.claimRewards();

        vm.warp(start + 45 days);
        uint256 remainder = _expectedReward(1_250, 8, 15 days);

        vm.expectEmit(true, false, false, true, address(vault));
        emit Unstaked(alice, 1_250, remainder);
        vm.prank(alice);
        vault.unstake();

        (,,,, bool active) = vault.stakingInfo(alice);
        assertFalse(active);
        assertEq(vault.totalStaked(), 0);
        assertEq(vault.balanceOf(alice, lp), 1_000);
        assertEq(vault.balanceOf(alice, governance), 250);
        assertEq(vault.balanceOf(alice, staking), 0);
        assertEq(vault.balanceOf(address(vault), lp), 0);
        assertEq(vault.balanceOf(alice, reward), claimed + remainder);
        assertEq(vault.getPendingRewards(alice), 0);

        (uint256[] memory ids, uint256[] memory amounts) = vault.stakedTokens(alice);
        assertEq(ids.length, 0);
        assertEq(amounts.length, 0);
    }

    function test_RevertWhen_UnstakeEarlyOrTwice() public {
        _stake(alice, 100, 30 days);

        vm.expectRevert(bytes("Staking period not ended"));
        vm.prank(alice);
        vault.unstake();

        vm.warp(block.timestamp + 30 days);
        vm.prank(alice);
        vault.unstake();

        vm.expectRevert(bytes("No active staking"));
        vm.prank(alice);
        vault.unstake();

        vm.expectRevert(bytes("No active staking"));
        vm.prank(alice);
        vault.claimRewards();
    }

    function test_RevertWhen_ReceiptTransferredAway() public {
        _stake(alice, 100, 30 days);

        vm.prank(alice);
        vault.safeTransferFrom(alice, bob, staking, 100, "");

        vm.warp(block.timestamp + 30 days);
        vm.expectRevert(abi.encodeWithSelector(ERC1155InsufficientBalance.selector, alice, 0, 100, staking));
        vm.prank(alice);
        vault.unstake();
    }

    function test_TwoUsers_AreIndependent() public {
        _stake(alice, 1_000, 90 days);
        _stake(bob, 3_000, 180 days);

        assertEq(vault.totalStaked(), 4_000);

        vm.warp(block.timestamp + 180 days);
        assertEq(vault.getPendingRewards(alice), _expectedReward(1_000, 10, 180 days));
        assertEq(vault.getPendingRewards(bob), _expectedReward(3_000, 12, 180 days));

        vm.prank(alice);
        vault.unstake();
        assertEq(vault.totalStaked(), 3_000);
        assertEq(vault.balanceOf(alice, lp), 1_000);

        (uint256 bobAmount,,,, bool bobActive) = vault.stakingInfo(bob);
        assertEq(bobAmount, 3_000);
        assertTrue(bobActive);
    }

    function test_Restake_AfterUnstake() public {
        _stake(alice, 80, 30 days);
        vm.warp(block.timestamp + 30 days);
        vm.prank(alice);
        vault.unstake();

        vault.mint(alice, lp, 20);
        _stake(alice, 100, 365 days);

        (uint256 amount,,, uint256 rate, bool active) = vault.stakingInfo(alice);
        assertEq(amount, 100);
        assertEq(rate, 15);
        assertTrue(active);
        assertEq(vault.balanceOf(alice, staking), 100);
    }

    function test_RevertWhen_ReenterOnUnstake() public {
        RewardReenter attacker = new RewardReenter(vault);
        vault.mint(address(attacker), lp, 10_000);

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = lp;
        amounts[0] = 10_000;
        attacker.stake(ids, amounts, 30 days);

        vm.warp(block.timestamp + 365 days);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        attacker.unstake();

        assertEq(vault.balanceOf(address(attacker), staking), 10_000);
        assertEq(vault.balanceOf(address(attacker), lp), 0);
        (,,,, bool active) = vault.stakingInfo(address(attacker));
        assertTrue(active);
    }

    function testFuzz_PendingMatchesFormula(uint256 amount, uint256 duration, uint256 elapsed) public {
        amount = bound(amount, 1, 1e24);
        duration = bound(duration, 30 days, 3 * 365 days);
        elapsed = bound(elapsed, 0, 2 * 365 days);

        vault.mint(alice, lp, amount);
        _stakeFromBalance(alice, amount, duration);

        vm.warp(block.timestamp + elapsed);
        uint256 rate = vault.rewardRateFor(duration);
        assertEq(vault.getPendingRewards(alice), (amount * rate * elapsed) / (365 days * 100));
    }

    function testFuzz_SplitClaimsDoNotExceedOneShot(uint256 amount, uint256 duration, uint256 first, uint256 second)
        public
    {
        amount = bound(amount, 1, 1e24);
        duration = bound(duration, 30 days, 365 days);
        first = bound(first, 1, 365 days);
        second = bound(second, 1, 365 days);

        vault.mint(alice, lp, amount);
        _stakeFromBalance(alice, amount, duration);
        uint256 rate = vault.rewardRateFor(duration);

        vm.warp(block.timestamp + first);
        _claimIfAny(alice);
        vm.warp(block.timestamp + second);
        _claimIfAny(alice);

        uint256 oneShot = (amount * rate * (first + second)) / (365 days * 100);
        assertLe(vault.totalRewards(alice), oneShot);
        assertEq(vault.getPendingRewards(alice), 0);
    }

    function _mintStakeable(address user, uint256 lpAmount, uint256 governanceAmount) internal {
        if (lpAmount != 0) vault.mint(user, lp, lpAmount);
        if (governanceAmount != 0) vault.mint(user, governance, governanceAmount);
    }

    function _stake(address user, uint256 amount, uint256 duration) internal {
        vault.mint(user, lp, amount);
        _stakeFromBalance(user, amount, duration);
    }

    function _stakeFromBalance(address user, uint256 amount, uint256 duration) internal {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = lp;
        amounts[0] = amount;
        vm.prank(user);
        vault.stake(ids, amounts, duration);
    }

    function _stakeBoth(address user, uint256 lpAmount, uint256 governanceAmount, uint256 duration) internal {
        _mintStakeable(user, lpAmount, governanceAmount);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = lp;
        ids[1] = governance;
        amounts[0] = lpAmount;
        amounts[1] = governanceAmount;
        vm.prank(user);
        vault.stake(ids, amounts, duration);
    }

    function _claimIfAny(address user) internal {
        if (vault.getPendingRewards(user) == 0) return;
        vm.prank(user);
        vault.claimRewards();
    }

    function _expectedReward(uint256 amount, uint256 rate, uint256 elapsed) internal pure returns (uint256) {
        return (amount * rate * elapsed) / (365 days * 100);
    }
}
