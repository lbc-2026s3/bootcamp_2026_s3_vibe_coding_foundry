// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Votes} from "openzeppelin-contracts/contracts/governance/utils/Votes.sol";
import {VotingToken} from "../../src/voting/VotingToken.sol";

contract VotingTokenTest is Test {
    VotingToken internal token;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant INITIAL = 1_000_000e18;

    function setUp() public {
        token = new VotingToken("Vote Token", "VOTE", owner, INITIAL);
    }

    function test_ConstructorMintsInitialSupplyToOwner() public view {
        assertEq(token.totalSupply(), INITIAL);
        assertEq(token.balanceOf(owner), INITIAL);
        assertEq(token.owner(), owner);
        // 未委托时票权为 0（OZ 设计：余额默认不算票）
        assertEq(token.getVotes(owner), 0);
    }

    function test_SelfDelegateActivatesVotingPower() public {
        vm.prank(owner);
        token.delegate(owner);

        assertEq(token.getVotes(owner), INITIAL);
        assertEq(token.delegates(owner), owner);
    }

    function test_DelegateToOtherTransfersVotingPower() public {
        vm.prank(owner);
        token.transfer(alice, 100e18);

        // alice 委托给 bob：alice 持币，bob 有票
        vm.prank(alice);
        token.delegate(bob);

        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.getVotes(alice), 0);
        assertEq(token.getVotes(bob), 100e18);
        assertEq(token.delegates(alice), bob);
    }

    function test_TransferMovesVotesBetweenDelegates() public {
        vm.prank(owner);
        token.delegate(owner);

        vm.prank(alice);
        token.delegate(alice);

        vm.prank(owner);
        token.transfer(alice, 40e18);

        assertEq(token.getVotes(owner), INITIAL - 40e18);
        assertEq(token.getVotes(alice), 40e18);
    }

    function test_GetPastVotesReflectsCheckpointAtBlock() public {
        vm.prank(owner);
        token.delegate(owner);

        uint256 checkpointBlock = block.number;
        assertEq(token.getVotes(owner), INITIAL);

        // 下一区块再转出；过去票权应仍为转账前
        vm.roll(block.number + 1);
        vm.prank(owner);
        token.transfer(alice, 10e18);

        assertEq(token.getPastVotes(owner, checkpointBlock), INITIAL);
        assertEq(token.getVotes(owner), INITIAL - 10e18);
    }

    function test_MintOnlyOwner() public {
        vm.prank(owner);
        token.mint(alice, 50e18);
        assertEq(token.balanceOf(alice), 50e18);

        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1e18);
    }

    function test_MintAfterSelfDelegateIncreasesVotes() public {
        vm.prank(alice);
        token.delegate(alice);

        vm.prank(owner);
        token.mint(alice, 75e18);

        assertEq(token.getVotes(alice), 75e18);
    }

    /// @dev 对应合约注释：已有余额并自委托后，再 mint 票数自动累加，无需再 delegate
    function test_MintToSelfDelegatedHolderIncreasesExistingVotes() public {
        vm.prank(owner);
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.delegate(alice);
        assertEq(token.getVotes(alice), 100e18);

        vm.prank(owner);
        token.mint(alice, 50e18);

        assertEq(token.balanceOf(alice), 150e18);
        assertEq(token.getVotes(alice), 150e18);
    }

    /// @dev 未 delegate 时 mint 只加余额、不加票
    function test_MintWithoutDelegateKeepsVotesZero() public {
        vm.prank(owner);
        token.mint(alice, 50e18);

        assertEq(token.balanceOf(alice), 50e18);
        assertEq(token.getVotes(alice), 0);
    }

    /// @dev 对应合约注释：to 已委托给他人时，新增票加到被委托人
    function test_MintToHolderWhoDelegatedToOtherIncreasesDelegateeVotes() public {
        vm.prank(alice);
        token.delegate(bob);

        vm.prank(owner);
        token.mint(alice, 50e18);

        assertEq(token.balanceOf(alice), 50e18);
        assertEq(token.getVotes(alice), 0);
        assertEq(token.getVotes(bob), 50e18);
    }

    /// @dev 整账户委托：改委托会把该地址全部票权挪走，不能按比例拆分
    function test_RedelegateMovesEntireVotingPower() public {
        vm.prank(owner);
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.delegate(alice);
        assertEq(token.getVotes(alice), 100e18);

        vm.prank(alice);
        token.delegate(bob);

        assertEq(token.getVotes(alice), 0);
        assertEq(token.getVotes(bob), 100e18);
        assertEq(token.delegates(alice), bob);
    }

    function test_PermitUpdatesAllowanceAndNonce() public {
        uint256 alicePk = 0xA11CE;
        address aliceSigner = vm.addr(alicePk);
        uint256 amount = 25e18;
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(owner);
        token.transfer(aliceSigner, amount);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            alicePk,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                            aliceSigner,
                            bob,
                            amount,
                            token.nonces(aliceSigner),
                            deadline
                        )
                    )
                )
            )
        );

        token.permit(aliceSigner, bob, amount, deadline, v, r, s);

        assertEq(token.allowance(aliceSigner, bob), amount);
        assertEq(token.nonces(aliceSigner), 1);
    }

    function test_RevertWhen_MintZeroOrZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(VotingToken.ZeroAmount.selector);
        token.mint(alice, 0);

        vm.expectRevert(VotingToken.ZeroAddress.selector);
        token.mint(address(0), 1e18);
        vm.stopPrank();
    }

    function test_RevertWhen_GetPastVotesInCurrentOrFutureBlock() public {
        vm.prank(owner);
        token.delegate(owner);

        // OZ: 只能查严格小于当前 clock 的 timepoint
        vm.expectRevert(
            abi.encodeWithSelector(Votes.ERC5805FutureLookup.selector, block.number, uint48(block.number))
        );
        token.getPastVotes(owner, block.number);
    }

    function testFuzz_SelfDelegateVotesEqualBalance(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        vm.prank(owner);
        token.mint(alice, amount);

        vm.prank(alice);
        token.delegate(alice);

        assertEq(token.getVotes(alice), amount);
        assertEq(token.getVotes(alice), token.balanceOf(alice));
    }
}
