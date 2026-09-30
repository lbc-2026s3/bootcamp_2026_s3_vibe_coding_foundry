// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Votes} from "openzeppelin-contracts/contracts/governance/utils/Votes.sol";
import {VotingToken} from "../../src/voting/VotingToken.sol";

/// @notice 本文件测的是「票权记账」，不是「对提案投票」。
/// @dev `VotingToken` 是 ERC20Votes 治理代币：管谁有多少可投票权（delegate / getVotes / getPastVotes），
///      不管把票投到哪个提案。没有 Governor，因此看不到 propose / castVote / 赞成反对。
///      真正投票需另接 OpenZeppelin `Governor` + `GovernorVotes`。
contract VotingTokenTest is Test {
    VotingToken internal token;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

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
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.delegates(alice), bob);
    }

    /// @dev 多人委托给同一人：被委托人票权累加，持币人各自余额不变
    function test_MultipleDelegatorsAccumulateVotesOnSameDelegatee() public {
        vm.startPrank(owner);
        token.transfer(alice, 30e18);
        token.transfer(carol, 70e18);
        vm.stopPrank();

        vm.prank(alice);
        token.delegate(bob);
        assertEq(token.getVotes(bob), 30e18);

        vm.prank(carol);
        token.delegate(bob);

        assertEq(token.balanceOf(alice), 30e18);
        assertEq(token.balanceOf(carol), 70e18);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.getVotes(alice), 0);
        assertEq(token.getVotes(carol), 0);
        assertEq(token.getVotes(bob), 100e18);
        assertEq(token.delegates(alice), bob);
        assertEq(token.delegates(carol), bob);
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

    /// @dev Alice 已委托给 Bob 后再转出：Bob 的票权随 Alice 余额减少
    function test_TransferAfterDelegateReducesDelegateeVotes() public {
        vm.prank(owner);
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.delegate(bob);
        assertEq(token.getVotes(bob), 100e18);

        vm.prank(alice);
        token.transfer(carol, 40e18);

        assertEq(token.balanceOf(alice), 60e18);
        assertEq(token.balanceOf(carol), 40e18);
        assertEq(token.getVotes(bob), 60e18);
        // carol 未委托：转出的 40 票休眠，不会自动落到 carol
        assertEq(token.getVotes(carol), 0);
        assertEq(token.getVotes(alice), 0);

        // carol 转回 alice
        vm.prank(carol);
        token.transfer(alice, 40e18);
        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.balanceOf(carol), 0);
        assertEq(token.getVotes(bob), 100e18);
        assertEq(token.getVotes(carol), 0);
        assertEq(token.getVotes(alice), 0);
    }

    /// @dev 同上，但用 permit 授权后由 spender `transferFrom` 转出
    function test_PermitTransferFromAfterDelegateReducesDelegateeVotes() public {
        uint256 alicePk = 0xA11CE;
        address aliceSigner = vm.addr(alicePk);

        vm.prank(owner);
        token.transfer(aliceSigner, 100e18);

        vm.prank(aliceSigner);
        token.delegate(bob);
        assertEq(token.getVotes(bob), 100e18);

        _permit(alicePk, aliceSigner, carol, 40e18);

        vm.prank(carol);
        token.transferFrom(aliceSigner, carol, 40e18);

        assertEq(token.balanceOf(aliceSigner), 60e18);
        assertEq(token.balanceOf(carol), 40e18);
        assertEq(token.getVotes(bob), 60e18);
        assertEq(token.getVotes(carol), 0);
        assertEq(token.getVotes(aliceSigner), 0);
        assertEq(token.allowance(aliceSigner, carol), 0);
        assertEq(token.nonces(aliceSigner), 1);
    }

    function _permit(uint256 pk, address owner_, address spender, uint256 value) private {
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _permitDigest(owner_, spender, value, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        token.permit(owner_, spender, value, deadline, v, r, s);
    }

    function _permitDigest(address owner_, address spender, uint256 value, uint256 deadline)
        private
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner_,
                spender,
                value,
                token.nonces(owner_),
                deadline
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
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
        assertEq(token.getPastVotes(alice, checkpointBlock), 0);
        assertEq(token.getVotes(owner), INITIAL - 10e18);
        assertEq(token.getVotes(alice), 0);
        vm.prank(alice);
        token.delegate(alice);
        assertEq(token.getVotes(alice), 10e18);
    }

    function test_MintOnlyOwner() public {
        vm.prank(owner);
        token.mint(alice, 50e18);
        assertEq(token.balanceOf(alice), 50e18);
        assertEq(token.getVotes(alice), 0);

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
        assertEq(token.balanceOf(bob), 0);
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
        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.balanceOf(bob), 0);
    }

    /// @dev OZ 无单独 undelegate：delegate(address(0)) 即撤销，余额保留、票权清零
    function test_DelegateToZeroRevokesVotingPower() public {
        vm.prank(owner);
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.delegate(alice);
        assertEq(token.getVotes(alice), 100e18);

        vm.prank(alice);
        token.delegate(address(0));

        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.getVotes(alice), 0);
        assertEq(token.delegates(alice), address(0));
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

        uint256 pastBlock = block.number;

        // OZ: 只能查严格小于当前 clock 的 timepoint
        vm.expectRevert(
            abi.encodeWithSelector(Votes.ERC5805FutureLookup.selector, pastBlock, uint48(pastBlock))
        );
        token.getPastVotes(owner, pastBlock);

        // 推进区块后，同一 timepoint 变成「过去」，查询应成功
        vm.roll(pastBlock + 1);
        assertEq(token.getPastVotes(owner, pastBlock), INITIAL);
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
