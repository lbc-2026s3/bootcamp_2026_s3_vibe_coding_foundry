// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EIP7702Utils} from "@openzeppelin/contracts/account/utils/EIP7702Utils.sol";
import {LabERC20, LabNFT} from "../../src/rescue/LabAssets.sol";
import {RescueDelegate} from "../../src/rescue/RescueDelegate.sol";

/// @notice A 的 ETH 为 0。单独给 A 打 ETH 会被同一把私钥转走；B 用 EIP-7702 付 gas 把资产转走。
///         forge test --match-path test/rescue/RescueCompromisedWallet.t.sol -vv
contract RescueCompromisedWalletTest is Test {
    /// @dev 实验私钥。不要用于任何有资金的地址。
    uint256 internal constant A_KEY = 0x1111111111111111111111111111111111111111111111111111111111111111;

    address internal A;
    address internal B;

    LabERC20 internal token;
    LabNFT internal nft;
    RescueDelegate internal delegate;

    uint256 internal constant NFT_COUNT = 3;
    uint256 internal tokenAmount;
    uint256[] internal nftIds;

    function setUp() public {
        A = vm.addr(A_KEY);
        B = makeAddr("sponsor");
        vm.deal(B, 1 ether);

        token = new LabERC20();
        nft = new LabNFT();
        delegate = new RescueDelegate(B);

        tokenAmount = 100 * 10 ** token.decimals();
        token.mint(A, tokenAmount);
        for (uint256 i = 0; i < NFT_COUNT; ++i) {
            nftIds.push(nft.mint(A));
        }
    }

    function test_victimHoldsAssetsWithZeroEth() public view {
        assertEq(A.balance, 0);
        assertEq(token.balanceOf(A), tokenAmount);
        assertEq(token.balanceOf(B), 0);
        for (uint256 i = 0; i < NFT_COUNT; ++i) {
            assertEq(nft.ownerOf(nftIds[i]), A);
        }
    }

    /// @dev 两笔独立交易：先给 A 打入 ETH，泄漏私钥的下一笔把 ETH 转走。NFT 还在 A 上。
    function test_fundingTransactionIsSweptAndNftsStay() public {
        address sweeper = makeAddr("sweeper");

        vm.prank(B);
        (bool funded,) = A.call{value: 1 ether}("");
        assertTrue(funded);
        assertEq(A.balance, 1 ether);

        vm.prank(A);
        (bool swept,) = sweeper.call{value: A.balance}("");
        assertTrue(swept);

        assertEq(A.balance, 0);
        assertEq(sweeper.balance, 1 ether);
        assertEq(token.balanceOf(A), tokenAmount);
        assertEq(nft.ownerOf(nftIds[0]), A);
    }

    function test_sponsorRescueMovesAssetsAndLeavesVictimEthAtZero() public {
        uint256 sponsorEth = B.balance;

        _rescue();

        assertEq(A.balance, 0);
        assertEq(B.balance, sponsorEth);
        assertEq(token.balanceOf(A), 0);
        assertEq(token.balanceOf(B), tokenAmount);
        for (uint256 i = 0; i < NFT_COUNT; ++i) {
            assertEq(nft.ownerOf(nftIds[i]), B);
        }
        assertEq(EIP7702Utils.fetchDelegate(A), address(delegate));
    }

    function test_strangerCannotCallRescue() public {
        _rescue();

        vm.prank(makeAddr("stranger"));
        vm.expectRevert(RescueDelegate.NotSafe.selector);
        RescueDelegate(A).rescue(address(token), tokenAmount, address(nft), nftIds);

        assertEq(token.balanceOf(makeAddr("stranger")), 0);
    }

    function test_emptyRescueReverts() public {
        _rescue();

        vm.prank(B);
        vm.expectRevert(RescueDelegate.NothingToRescue.selector);
        RescueDelegate(A).rescue(address(token), 0, address(nft), new uint256[](0));
    }

    /// @dev EIP-7702：执行回滚时，资产转账撤销，但已经写入的委托保留。
    ///      委托只能把资产转到 B，所以 B 可以不再签名、直接再调一次。
    function test_failedRescueRollsBackAssetsAndKeepsDelegation() public {
        uint256[] memory badIds = new uint256[](1);
        badIds[0] = 999;

        vm.signAndAttachDelegation(address(delegate), A_KEY);
        vm.prank(B);
        vm.expectRevert();
        RescueDelegate(A).rescue(address(token), tokenAmount, address(nft), badIds);

        assertEq(A.balance, 0);
        assertEq(token.balanceOf(A), tokenAmount);
        assertEq(token.balanceOf(B), 0);
        assertEq(nft.ownerOf(nftIds[0]), A);
        assertEq(EIP7702Utils.fetchDelegate(A), address(delegate));

        vm.prank(B);
        RescueDelegate(A).rescue(address(token), tokenAmount, address(nft), nftIds);

        assertEq(A.balance, 0);
        assertEq(token.balanceOf(A), 0);
        assertEq(token.balanceOf(B), tokenAmount);
        assertEq(nft.ownerOf(nftIds[0]), B);
    }

    function test_callingImplementationDoesNotMoveVictimTokens() public {
        vm.expectRevert();
        delegate.rescue(address(token), tokenAmount, address(nft), nftIds);

        assertEq(token.balanceOf(A), tokenAmount);
        assertEq(A.balance, 0);
    }

    function _rescue() internal {
        vm.signAndAttachDelegation(address(delegate), A_KEY);
        vm.prank(B);
        RescueDelegate(A).rescue(address(token), tokenAmount, address(nft), nftIds);
    }
}
