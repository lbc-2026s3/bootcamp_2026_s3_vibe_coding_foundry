// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SocialRecoveryWallet} from "../../src/wallet/SocialRecoveryWallet.sol";

/// @notice 社交恢复的四段流程：空闲转账、收集确认、安全期内取消、到期换主人。
///         forge test --match-path test/wallet/SocialRecoveryWallet.t.sol -vv
contract SocialRecoveryWalletTest is Test {
    uint256 internal constant SECURITY_PERIOD = 3 days;
    uint256 internal constant START = 1_000_000;

    SocialRecoveryWallet internal wallet;

    address internal owner = makeAddr("owner");
    address internal guardian1 = makeAddr("guardian1");
    address internal guardian2 = makeAddr("guardian2");
    address internal guardian3 = makeAddr("guardian3");
    address internal newOwner = makeAddr("newOwner");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        vm.warp(START);
        wallet = new SocialRecoveryWallet(owner, _guardians(), 2, SECURITY_PERIOD);
        vm.deal(address(wallet), 1 ether);
    }

    function test_owner_spends_while_idle() public {
        vm.prank(owner);
        wallet.execute(stranger, 0.4 ether, "");

        assertEq(stranger.balance, 0.4 ether);
        assertEq(address(wallet).balance, 0.6 ether);
        assertEq(uint256(wallet.phase()), uint256(SocialRecoveryWallet.Phase.Idle));
    }

    function test_revert_guardian_cannot_spend() public {
        vm.prank(guardian1);
        vm.expectRevert(abi.encodeWithSelector(SocialRecoveryWallet.NotOwner.selector, guardian1));
        wallet.execute(guardian1, 1 ether, "");
    }

    function test_lost_key_two_of_three_then_new_owner_spends() public {
        _collectThreshold();

        (address proposed, uint256 confirmations, uint256 executableAt) = wallet.pendingRecovery();
        assertEq(proposed, newOwner);
        assertEq(confirmations, 2);
        assertEq(executableAt, START + SECURITY_PERIOD);
        assertEq(wallet.owner(), owner);
        assertEq(uint256(wallet.phase()), uint256(SocialRecoveryWallet.Phase.Waiting));

        vm.warp(executableAt);
        assertEq(uint256(wallet.phase()), uint256(SocialRecoveryWallet.Phase.Ready));

        vm.expectEmit(true, true, false, true, address(wallet));
        emit SocialRecoveryWallet.OwnershipTransferred(owner, newOwner);

        vm.prank(stranger);
        wallet.executeRecovery();

        assertEq(wallet.owner(), newOwner);
        assertEq(uint256(wallet.phase()), uint256(SocialRecoveryWallet.Phase.Idle));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(SocialRecoveryWallet.NotOwner.selector, owner));
        wallet.execute(owner, 1 ether, "");

        vm.prank(newOwner);
        wallet.execute(newOwner, 1 ether, "");
        assertEq(newOwner.balance, 1 ether);
        assertEq(address(wallet).balance, 0);
    }

    function test_owner_cancels_rogue_guardians_during_security_period() public {
        _collectThreshold();

        vm.warp(START + SECURITY_PERIOD - 1);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(SocialRecoveryWallet.SecurityPeriodActive.selector, START + SECURITY_PERIOD)
        );
        wallet.executeRecovery();

        vm.expectEmit(true, true, false, true, address(wallet));
        emit SocialRecoveryWallet.RecoveryCancelled(newOwner, owner);

        vm.prank(owner);
        wallet.cancelRecovery();

        assertEq(wallet.owner(), owner);
        assertEq(uint256(wallet.phase()), uint256(SocialRecoveryWallet.Phase.Idle));
        assertFalse(wallet.hasConfirmed(guardian1));

        vm.prank(owner);
        wallet.execute(owner, 1 ether, "");
        assertEq(owner.balance, 1 ether);
    }

    function test_one_confirmation_does_not_start_security_period() public {
        vm.prank(guardian1);
        wallet.initiateRecovery(newOwner);

        (, uint256 confirmations, uint256 executableAt) = wallet.pendingRecovery();
        assertEq(confirmations, 1);
        assertEq(executableAt, 0);
        assertEq(uint256(wallet.phase()), uint256(SocialRecoveryWallet.Phase.Collecting));

        vm.warp(START + 30 days);
        vm.expectRevert(SocialRecoveryWallet.RecoveryNotReady.selector);
        wallet.executeRecovery();
    }

    function test_spending_and_guardian_changes_lock_as_soon_as_recovery_starts() public {
        vm.prank(guardian1);
        wallet.initiateRecovery(newOwner);

        vm.prank(owner);
        vm.expectRevert(SocialRecoveryWallet.RecoveryInProgress.selector);
        wallet.execute(owner, 1 ether, "");

        address[] memory next = new address[](2);
        next[0] = makeAddr("next1");
        next[1] = makeAddr("next2");
        vm.prank(owner);
        vm.expectRevert(SocialRecoveryWallet.RecoveryInProgress.selector);
        wallet.replaceGuardians(next);

        vm.prank(owner);
        wallet.cancelRecovery();

        vm.prank(owner);
        wallet.replaceGuardians(next);
        assertFalse(wallet.isGuardian(guardian1));
        assertTrue(wallet.isGuardian(next[0]));
    }

    function test_revert_same_guardian_confirms_twice() public {
        vm.prank(guardian1);
        wallet.initiateRecovery(newOwner);

        vm.prank(guardian1);
        vm.expectRevert(abi.encodeWithSelector(SocialRecoveryWallet.AlreadyConfirmed.selector, guardian1));
        wallet.confirmRecovery();
    }

    function test_revert_third_guardian_after_threshold() public {
        _collectThreshold();

        vm.prank(guardian3);
        vm.expectRevert(
            abi.encodeWithSelector(SocialRecoveryWallet.RecoveryAlreadyReady.selector, START + SECURITY_PERIOD)
        );
        wallet.confirmRecovery();
    }

    function test_revert_stranger_and_second_recovery() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(SocialRecoveryWallet.NotGuardian.selector, stranger));
        wallet.initiateRecovery(newOwner);

        vm.prank(guardian1);
        wallet.initiateRecovery(newOwner);

        vm.prank(guardian2);
        vm.expectRevert(SocialRecoveryWallet.RecoveryInProgress.selector);
        wallet.initiateRecovery(makeAddr("other"));
    }

    function test_revert_replace_below_threshold_and_old_guardian_after_replace() public {
        address[] memory tooSmall = new address[](1);
        tooSmall[0] = makeAddr("only");
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(SocialRecoveryWallet.InvalidThreshold.selector, 2, 1));
        wallet.replaceGuardians(tooSmall);

        address[] memory next = new address[](2);
        next[0] = makeAddr("next1");
        next[1] = makeAddr("next2");
        vm.prank(owner);
        wallet.replaceGuardians(next);

        vm.prank(guardian1);
        vm.expectRevert(abi.encodeWithSelector(SocialRecoveryWallet.NotGuardian.selector, guardian1));
        wallet.initiateRecovery(newOwner);
    }

    function test_threshold_one_enters_waiting_on_initiate() public {
        SocialRecoveryWallet single = new SocialRecoveryWallet(owner, _oneGuardian(), 1, SECURITY_PERIOD);

        vm.prank(guardian1);
        single.initiateRecovery(newOwner);

        assertEq(uint256(single.phase()), uint256(SocialRecoveryWallet.Phase.Waiting));
        (, uint256 confirmations, uint256 executableAt) = single.pendingRecovery();
        assertEq(confirmations, 1);
        assertEq(executableAt, START + SECURITY_PERIOD);
    }

    function test_revert_constructor_rejects_bad_sets() public {
        address[] memory dup = _guardians();
        dup[2] = guardian1;
        vm.expectRevert(SocialRecoveryWallet.InvalidGuardians.selector);
        new SocialRecoveryWallet(owner, dup, 2, SECURITY_PERIOD);

        address[] memory withOwner = _guardians();
        withOwner[0] = owner;
        vm.expectRevert(SocialRecoveryWallet.InvalidGuardians.selector);
        new SocialRecoveryWallet(owner, withOwner, 2, SECURITY_PERIOD);

        vm.expectRevert(abi.encodeWithSelector(SocialRecoveryWallet.InvalidThreshold.selector, 4, 3));
        new SocialRecoveryWallet(owner, _guardians(), 4, SECURITY_PERIOD);

        vm.expectRevert(SocialRecoveryWallet.InvalidSecurityPeriod.selector);
        new SocialRecoveryWallet(owner, _guardians(), 2, 0);
    }

    function test_reentrancy_cannot_pull_twice() public {
        ReenteringReceiver attacker = new ReenteringReceiver(wallet);
        vm.deal(address(wallet), 2 ether);

        vm.prank(owner);
        wallet.execute(address(attacker), 1 ether, "");

        assertEq(address(attacker).balance, 1 ether);
        assertEq(address(wallet).balance, 1 ether);
        assertEq(attacker.calls(), 1);
    }

    function testFuzz_recovery_executes_only_after_security_period(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, 30 days);
        _collectThreshold();

        vm.warp(START + elapsed);
        if (elapsed < SECURITY_PERIOD) {
            vm.expectRevert(
                abi.encodeWithSelector(SocialRecoveryWallet.SecurityPeriodActive.selector, START + SECURITY_PERIOD)
            );
            wallet.executeRecovery();
            assertEq(wallet.owner(), owner);
        } else {
            wallet.executeRecovery();
            assertEq(wallet.owner(), newOwner);
        }
    }

    function _collectThreshold() internal {
        vm.prank(guardian1);
        wallet.initiateRecovery(newOwner);
        vm.prank(guardian2);
        wallet.confirmRecovery();
    }

    function _guardians() internal view returns (address[] memory list) {
        list = new address[](3);
        list[0] = guardian1;
        list[1] = guardian2;
        list[2] = guardian3;
    }

    function _oneGuardian() internal view returns (address[] memory list) {
        list = new address[](1);
        list[0] = guardian1;
    }
}

contract ReenteringReceiver {
    SocialRecoveryWallet internal immutable wallet;
    uint256 public calls;

    constructor(SocialRecoveryWallet _wallet) {
        wallet = _wallet;
    }

    receive() external payable {
        calls += 1;
        if (address(wallet).balance == 0) return;
        try wallet.execute(address(this), address(wallet).balance, "") {} catch {}
    }
}
