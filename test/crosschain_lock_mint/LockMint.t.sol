// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {CanonicalToken} from "../../src/crosschain_lock_mint/CanonicalToken.sol";
import {LockVault} from "../../src/crosschain_lock_mint/LockVault.sol";
import {WrappedToken} from "../../src/crosschain_lock_mint/WrappedToken.sol";

contract LockMintTest is Test {
    uint64 internal constant HOME = 1;
    uint64 internal constant REMOTE = 2;
    uint256 internal constant AMOUNT = 100e18;

    address internal owner = makeAddr("owner");
    address internal relayer = makeAddr("relayer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    CanonicalToken internal token;
    LockVault internal vault;
    WrappedToken internal wrapped;

    function _lock(address from, address to, uint256 amount) internal returns (bytes32 messageId) {
        vm.startPrank(from);
        token.approve(address(vault), amount);
        messageId = vault.lock(to, amount);
        vm.stopPrank();
    }

    function _relayMint(address sender, address recipient, uint256 amount, uint64 nonce) internal {
        vm.prank(relayer);
        wrapped.mint(HOME, REMOTE, nonce, sender, recipient, amount);
    }

    function _relayRelease(address sender, address recipient, uint256 amount, uint64 nonce) internal {
        vm.prank(relayer);
        vault.release(REMOTE, HOME, nonce, sender, recipient, amount);
    }

    function setUp() public {
        vm.prank(owner);
        token = new CanonicalToken();

        vault = new LockVault(IERC20(address(token)), HOME, REMOTE, relayer, owner);
        wrapped = new WrappedToken(REMOTE, HOME, relayer, owner);

        vm.prank(owner);
        token.transfer(alice, 1_000e18);
    }

    function test_roundTripLockMintBurnRelease() public {
        bytes32 lockId = _lock(alice, bob, AMOUNT);
        assertEq(vault.s_nonce(), 1);
        assertEq(lockId, vault.computeMessageId(HOME, REMOTE, 1, alice, bob, AMOUNT));
        assertEq(vault.s_locked(), AMOUNT);
        assertEq(token.balanceOf(address(vault)), AMOUNT);
        assertEq(wrapped.totalSupply(), 0);

        _relayMint(alice, bob, AMOUNT, 1);
        assertEq(vault.s_locked(), AMOUNT);
        assertEq(token.balanceOf(address(vault)), AMOUNT);
        assertEq(wrapped.totalSupply(), AMOUNT);
        assertEq(wrapped.balanceOf(bob), AMOUNT);

        vm.prank(bob);
        bytes32 burnId = wrapped.burn(AMOUNT, alice);
        assertEq(wrapped.s_nonce(), 1);
        assertEq(burnId, wrapped.computeMessageId(REMOTE, HOME, 1, bob, alice, AMOUNT));
        assertEq(wrapped.totalSupply(), 0);
        assertEq(vault.s_locked(), AMOUNT);
        assertEq(token.balanceOf(address(vault)), AMOUNT);

        _relayRelease(bob, alice, AMOUNT, 1);
        assertEq(vault.s_locked(), 0);
        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(wrapped.totalSupply(), 0);
        assertEq(token.balanceOf(alice), 1_000e18);
    }

    function test_relayerNeverMintsDestBalanceUnchanged() public {
        _lock(alice, bob, AMOUNT);

        assertEq(token.balanceOf(address(vault)), AMOUNT);
        assertEq(wrapped.balanceOf(bob), 0);
        assertEq(wrapped.totalSupply(), 0);
        assertEq(vault.s_locked(), AMOUNT);
    }

    function test_RevertWhen_MintNotRelayer() public {
        _lock(alice, bob, AMOUNT);

        vm.expectRevert(WrappedToken.NotRelayer.selector);
        wrapped.mint(HOME, REMOTE, 1, alice, bob, AMOUNT);
    }

    function test_RevertWhen_ReleaseNotRelayer() public {
        _lock(alice, bob, AMOUNT);
        _relayMint(alice, bob, AMOUNT, 1);
        vm.prank(bob);
        wrapped.burn(AMOUNT, alice);

        vm.expectRevert(LockVault.NotRelayer.selector);
        vault.release(REMOTE, HOME, 1, bob, alice, AMOUNT);
    }

    function test_RevertWhen_ReplayMint() public {
        _lock(alice, bob, AMOUNT);
        _relayMint(alice, bob, AMOUNT, 1);

        bytes32 messageId = wrapped.computeMessageId(HOME, REMOTE, 1, alice, bob, AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(WrappedToken.AlreadyProcessed.selector, messageId));
        _relayMint(alice, bob, AMOUNT, 1);
    }

    function test_RevertWhen_ReplayRelease() public {
        _lock(alice, bob, AMOUNT);
        _relayMint(alice, bob, AMOUNT, 1);
        vm.prank(bob);
        wrapped.burn(AMOUNT, alice);
        _relayRelease(bob, alice, AMOUNT, 1);

        bytes32 messageId = vault.computeMessageId(REMOTE, HOME, 1, bob, alice, AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(LockVault.AlreadyProcessed.selector, messageId));
        _relayRelease(bob, alice, AMOUNT, 1);
    }

    function test_RevertWhen_LockZeroAmount() public {
        vm.startPrank(alice);
        token.approve(address(vault), 1);
        vm.expectRevert(LockVault.ZeroAmount.selector);
        vault.lock(bob, 0);
        vm.stopPrank();
    }

    function test_RevertWhen_LockZeroRecipient() public {
        vm.startPrank(alice);
        token.approve(address(vault), AMOUNT);
        vm.expectRevert(LockVault.ZeroAddress.selector);
        vault.lock(address(0), AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_BurnZeroAmount() public {
        _lock(alice, bob, AMOUNT);
        _relayMint(alice, bob, AMOUNT, 1);

        vm.prank(bob);
        vm.expectRevert(WrappedToken.ZeroAmount.selector);
        wrapped.burn(0, alice);
    }

    function test_RevertWhen_MintUnknownSourceDomain() public {
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(WrappedToken.UnknownSourceDomain.selector, uint64(99)));
        wrapped.mint(99, REMOTE, 1, alice, bob, AMOUNT);
    }

    function test_RevertWhen_MintInvalidDestDomain() public {
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(WrappedToken.InvalidDestDomain.selector, HOME));
        wrapped.mint(HOME, HOME, 1, alice, bob, AMOUNT);
    }

    function test_RevertWhen_ReleaseMoreThanLocked() public {
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(LockVault.InsufficientLocked.selector, uint256(0), AMOUNT));
        vault.release(REMOTE, HOME, 1, bob, alice, AMOUNT);
    }

    function test_RevertWhen_SetRelayerNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vault.setRelayer(alice);
    }

    function test_setRelayerThenOldRelayerCannotMint() public {
        _lock(alice, bob, AMOUNT);

        address newRelayer = makeAddr("newRelayer");
        vm.prank(owner);
        wrapped.setRelayer(newRelayer);

        vm.prank(relayer);
        vm.expectRevert(WrappedToken.NotRelayer.selector);
        wrapped.mint(HOME, REMOTE, 1, alice, bob, AMOUNT);

        vm.prank(newRelayer);
        wrapped.mint(HOME, REMOTE, 1, alice, bob, AMOUNT);
        assertEq(wrapped.balanceOf(bob), AMOUNT);
    }

    function test_RevertWhen_ConstructorSameDomain() public {
        vm.expectRevert(LockVault.SameDomain.selector);
        new LockVault(IERC20(address(token)), HOME, HOME, relayer, owner);
    }

    function test_messageIdMatchesAcrossContracts() public view {
        bytes32 vaultId = vault.computeMessageId(HOME, REMOTE, 1, alice, bob, AMOUNT);
        bytes32 wrappedId = wrapped.computeMessageId(HOME, REMOTE, 1, alice, bob, AMOUNT);
        assertEq(vaultId, wrappedId);
    }

    function test_twoIdenticalLocksUseDistinctNonces() public {
        bytes32 first = _lock(alice, bob, AMOUNT);
        bytes32 second = _lock(alice, bob, AMOUNT);

        assertEq(vault.s_nonce(), 2);
        assertEq(first, vault.computeMessageId(HOME, REMOTE, 1, alice, bob, AMOUNT));
        assertEq(second, vault.computeMessageId(HOME, REMOTE, 2, alice, bob, AMOUNT));
        assertTrue(first != second);

        _relayMint(alice, bob, AMOUNT, 1);
        _relayMint(alice, bob, AMOUNT, 2);
        assertEq(wrapped.balanceOf(bob), AMOUNT * 2);
        assertEq(wrapped.totalSupply(), AMOUNT * 2);
    }
}
