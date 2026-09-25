// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StakingPool} from "../../src/staking/StakingPool.sol";
import {KKToken} from "../../src/staking/KKToken.sol";

contract EthReenter {
    StakingPool public pool;
    bool public attack;

    constructor(StakingPool pool_) {
        pool = pool_;
    }

    function stake() external payable {
        pool.stake{value: msg.value}();
    }

    function withdraw(uint256 amount) external {
        attack = true;
        pool.withdraw(amount);
    }

    receive() external payable {
        if (!attack) return;
        attack = false;
        pool.withdraw(1 ether);
    }
}

contract StakingPoolTest is Test {
    StakingPool public pool;
    KKToken public kk;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        pool = new StakingPool();
        kk = pool.kkToken();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function _stake(address user, uint256 amount) internal {
        vm.prank(user);
        pool.stake{value: amount}();
    }

    function test_Stake_RecordsEthAndMintsNothingSameBlock() public {
        _stake(alice, 4 ether);

        (uint256 amount, uint256 rewardDebt) = pool.userInfo(alice);
        assertEq(amount, 4 ether);
        assertEq(rewardDebt, 0);
        assertEq(pool.totalStaked(), 4 ether);
        assertEq(address(pool).balance, 4 ether);
        assertEq(kk.totalSupply(), 0);
        assertEq(kk.minter(), address(pool));
    }

    function test_RevertWhen_StakeZero() public {
        vm.prank(alice);
        vm.expectRevert(StakingPool.ZeroAmount.selector);
        pool.stake{value: 0}();
    }

    function test_SingleStaker_EarnsTenPerBlock() public {
        _stake(alice, 1 ether);
        vm.roll(block.number + 5);

        assertEq(pool.pendingReward(alice), 50 ether);

        uint256 before = kk.balanceOf(alice);
        vm.prank(alice);
        pool.claim();

        assertEq(kk.balanceOf(alice) - before, 50 ether);
        (uint256 amount,) = pool.userInfo(alice);
        assertEq(amount, 1 ether);
        assertEq(pool.pendingReward(alice), 0);
        assertEq(address(pool).balance, 1 ether);
    }

    function test_TwoStakers_SplitByStakeAmount() public {
        _stake(alice, 3 ether);
        _stake(bob, 1 ether);
        // 同一区块入金，下一块起按 3:1 分 10 KK
        vm.roll(block.number + 10);

        assertEq(pool.pendingReward(alice), 75 ether);
        assertEq(pool.pendingReward(bob), 25 ether);

        vm.prank(alice);
        pool.claim();
        vm.prank(bob);
        pool.claim();

        assertEq(kk.balanceOf(alice), 75 ether);
        assertEq(kk.balanceOf(bob), 25 ether);
        assertEq(kk.totalSupply(), 100 ether);
    }

    function test_LateStaker_DoesNotTakeEarlierRewards() public {
        _stake(alice, 2 ether);
        vm.roll(block.number + 4);

        // Bob 入金只更新全局 acc，Alice 的 40 KK 仍记在她的 pending 里，直到她自己领取
        _stake(bob, 2 ether);
        assertEq(pool.pendingReward(alice), 40 ether);
        assertEq(kk.balanceOf(bob), 0);

        vm.roll(block.number + 4);
        vm.prank(alice);
        pool.claim();
        vm.prank(bob);
        pool.claim();

        assertEq(kk.balanceOf(alice), 60 ether);
        assertEq(kk.balanceOf(bob), 20 ether);
    }

    function test_Withdraw_ReturnsPrincipalAndStopsRewards() public {
        _stake(alice, 5 ether);
        vm.roll(block.number + 3);

        uint256 ethBefore = alice.balance;
        vm.prank(alice);
        pool.withdraw(5 ether);

        assertEq(alice.balance - ethBefore, 5 ether);
        assertEq(kk.balanceOf(alice), 30 ether);
        (uint256 amount,) = pool.userInfo(alice);
        assertEq(amount, 0);
        assertEq(pool.totalStaked(), 0);
        assertEq(address(pool).balance, 0);

        vm.roll(block.number + 10);
        assertEq(pool.pendingReward(alice), 0);
        assertEq(kk.totalSupply(), 30 ether);
    }

    function test_PartialWithdraw_RemainingStakeKeepsEarning() public {
        _stake(alice, 2 ether);
        vm.roll(block.number + 2);

        vm.prank(alice);
        pool.withdraw(1 ether);

        assertEq(kk.balanceOf(alice), 20 ether);
        (uint256 amount,) = pool.userInfo(alice);
        assertEq(amount, 1 ether);

        vm.roll(block.number + 2);
        assertEq(pool.pendingReward(alice), 20 ether);
    }

    function test_RevertWhen_WithdrawTooMuch() public {
        _stake(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(StakingPool.InsufficientStake.selector);
        pool.withdraw(2 ether);
    }

    function test_Claim_DoesNotChangeStake() public {
        _stake(alice, 2 ether);
        _stake(bob, 2 ether);
        vm.roll(block.number + 8);

        vm.prank(alice);
        pool.claim();

        (uint256 amount,) = pool.userInfo(alice);
        assertEq(amount, 2 ether);
        assertEq(pool.totalStaked(), 4 ether);
        assertEq(kk.balanceOf(alice), 40 ether);
        assertEq(pool.pendingReward(bob), 40 ether);
    }

    function test_Restake_HarvestsThenEarnsOnNewAmount() public {
        _stake(alice, 1 ether);
        vm.roll(block.number + 2);
        _stake(alice, 1 ether);

        assertEq(kk.balanceOf(alice), 20 ether);
        (uint256 amount,) = pool.userInfo(alice);
        assertEq(amount, 2 ether);

        vm.roll(block.number + 2);
        assertEq(pool.pendingReward(alice), 20 ether);
    }

    function test_EmptyPool_SkipsEmission() public {
        vm.roll(block.number + 20);
        assertEq(kk.totalSupply(), 0);

        _stake(alice, 1 ether);
        vm.roll(block.number + 1);
        assertEq(pool.pendingReward(alice), 10 ether);
    }

    function test_RevertWhen_OutsiderMintsKK() public {
        vm.expectRevert(KKToken.OnlyMinter.selector);
        kk.mint(alice, 1 ether);
    }

    function test_Withdraw_ReentrancyDoesNotDoublePay() public {
        EthReenter attacker = new EthReenter(pool);
        vm.deal(address(attacker), 2 ether);
        attacker.stake{value: 2 ether}();

        vm.roll(block.number + 1);
        vm.expectRevert();
        attacker.withdraw(1 ether);

        (uint256 amount,) = pool.userInfo(address(attacker));
        assertEq(amount, 2 ether);
        assertEq(address(pool).balance, 2 ether);
    }
}
