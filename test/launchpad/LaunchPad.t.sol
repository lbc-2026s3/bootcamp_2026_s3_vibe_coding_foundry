// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, stdStorage, StdStorage} from "forge-std/Test.sol";
import {UniswapV2Factory} from "uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "uniswapv2/UniswapV2Router02.sol";
import {IUniswapV2Pair} from "uniswapv2/interfaces/IUniswapV2Pair.sol";
import {WETH9} from "uniswapv2/WETH9.sol";
import {LaunchPad} from "../../src/launchpad/LaunchPad.sol";
import {MemeToken} from "../../src/launchpad/MemeToken.sol";

contract RejectEthCreator {
    error Nope();

    receive() external payable {
        revert Nope();
    }

    fallback() external payable {
        revert Nope();
    }
}

contract LaunchPadTest is Test {
    using stdStorage for StdStorage;

    LaunchPad internal launchPad;
    UniswapV2Factory internal uniFactory;
    UniswapV2Router02 internal router;
    WETH9 internal weth;

    address internal creator = makeAddr("creator");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant PER_MINT = 1_000e18;
    uint256 internal constant PRICE = 1 ether;
    uint256 internal constant MINT_UNIT = 1_990e18;
    uint256 internal constant MAX_SUPPLY = MINT_UNIT * 100;
    // 100 次 mint × 0.99 ETH = 99 ETH，门槛须 ≤ 99
    uint256 internal constant GRADUATION_ETH = 50 ether;

    function setUp() public {
        weth = new WETH9();
        uniFactory = new UniswapV2Factory(address(this));
        router = new UniswapV2Router02(address(uniFactory), address(weth));
        launchPad = new LaunchPad(address(router));

        vm.deal(alice, 200 ether);
        vm.deal(bob, 200 ether);
        vm.deal(creator, 0);
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _ethForLp() internal pure returns (uint256) {
        return PRICE - (PRICE * 100) / 10_000;
    }

    function _memeForLp() internal pure returns (uint256) {
        return (_ethForLp() * PER_MINT) / PRICE;
    }

    function _deploy() internal returns (MemeToken token) {
        vm.prank(creator);
        token = MemeToken(launchPad.deployMeme("DOGE", MAX_SUPPLY, PER_MINT, PRICE, GRADUATION_ETH));
    }

    function _deployWithGraduation(uint256 graduationEth_) internal returns (MemeToken token) {
        vm.prank(creator);
        token = MemeToken(launchPad.deployMeme("DOGE", MAX_SUPPLY, PER_MINT, PRICE, graduationEth_));
    }

    function _mint(address who, address token) internal {
        vm.prank(who);
        launchPad.mintMeme{value: PRICE}(token);
    }

    function test_DeployMeme_SetsPriceAndClone() public {
        MemeToken token = _deploy();
        assertTrue(launchPad.isMeme(address(token)));
        assertEq(token.creator(), creator);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.price(), PRICE);
        assertEq(launchPad.graduationEth(address(token)), GRADUATION_ETH);
        assertEq(address(token).code.length, 45);
    }

    function test_MintMeme_LocksEth_NoPoolYet() public {
        MemeToken token = _deploy();
        uint256 ethForLp = _ethForLp();
        uint256 memeForLp = _memeForLp();
        uint256 fee = PRICE - ethForLp;

        _mint(alice, address(token));

        assertEq(token.balanceOf(alice), PER_MINT);
        assertEq(launchPad.ethRaisedForLp(address(token)), ethForLp);
        assertEq(launchPad.memeReservedForLp(address(token)), memeForLp);
        assertEq(launchPad.pendingFees(creator), fee);
        assertFalse(launchPad.graduated(address(token)));
        assertFalse(launchPad.hasPool(address(token)));

        vm.prank(creator);
        launchPad.claimFees();
        assertEq(creator.balance, fee);
    }

    function test_SecondMint_StillLocked_Accumulates() public {
        MemeToken token = _deploy();
        _mint(alice, address(token));
        _mint(bob, address(token));

        assertEq(token.balanceOf(bob), PER_MINT);
        assertEq(launchPad.ethRaisedForLp(address(token)), _ethForLp() * 2);
        assertEq(launchPad.memeReservedForLp(address(token)), _memeForLp() * 2);
        assertFalse(launchPad.hasPool(address(token)));
        assertEq(launchPad.pendingFees(creator), (PRICE * 100) / 10_000 * 2);
    }

    function test_Graduate_AddsLiquidityOnce_ThenBuyWorks() public {
        MemeToken token = _deployWithGraduation(0.99 ether);
        uint256 ethForLp = _ethForLp();
        uint256 memeForLp = _memeForLp();

        _mint(alice, address(token));

        assertTrue(launchPad.graduated(address(token)));
        assertEq(launchPad.ethRaisedForLp(address(token)), 0);
        assertEq(launchPad.memeReservedForLp(address(token)), 0);

        address pair = uniFactory.getPair(address(token), address(weth));
        assertTrue(pair != address(0));
        (uint256 reserveMeme, uint256 reserveWeth) = launchPad.getReserves(address(token));
        assertEq(reserveWeth, ethForLp);
        assertEq(reserveMeme, memeForLp);
        assertEq(reserveWeth * PER_MINT, reserveMeme * PRICE);
        assertGt(IUniswapV2Pair(pair).balanceOf(address(0)), 0);

        vm.prank(bob);
        vm.expectRevert(LaunchPad.AlreadyGraduated.selector);
        launchPad.mintMeme{value: PRICE}(address(token));

        uint256 buyEth = 0.01 ether;
        uint256 expected = launchPad.previewBuy(address(token), buyEth);
        vm.prank(bob);
        launchPad.buyMeme{value: buyEth}(address(token), expected, _deadline());
        assertEq(token.balanceOf(bob), expected);
    }

    function test_BuyBeforeGraduate_Reverts() public {
        MemeToken token = _deploy();
        _mint(alice, address(token));
        vm.prank(bob);
        vm.expectRevert(LaunchPad.NotGraduated.selector);
        launchPad.buyMeme{value: 0.1 ether}(address(token), 0, _deadline());
    }

    function test_ManualGraduate_WhenReady() public {
        MemeToken token = _deployWithGraduation(2 ether);
        _mint(alice, address(token));
        _mint(bob, address(token));
        assertFalse(launchPad.graduated(address(token)));

        uint256 ethLp = launchPad.ethRaisedForLp(address(token));
        uint256 memeLp = launchPad.memeReservedForLp(address(token));

        vm.expectRevert(LaunchPad.GraduationNotReady.selector);
        launchPad.graduate(address(token), memeLp, ethLp, _deadline());

        _mint(alice, address(token));
        assertTrue(launchPad.graduated(address(token)));
        assertTrue(launchPad.hasPool(address(token)));
    }

    function test_RejectEthCreator_MintStillWorks() public {
        RejectEthCreator badCreator = new RejectEthCreator();
        vm.prank(address(badCreator));
        MemeToken token =
            MemeToken(launchPad.deployMeme("BAD", MAX_SUPPLY, PER_MINT, PRICE, GRADUATION_ETH));

        _mint(alice, address(token));
        assertEq(launchPad.pendingFees(address(badCreator)), (PRICE * 100) / 10_000);

        vm.prank(address(badCreator));
        vm.expectRevert(LaunchPad.EthTransferFailed.selector);
        launchPad.claimFees();
    }

    function test_RevertWhen_BuySlippageTooTight() public {
        MemeToken token = _deployWithGraduation(0.99 ether);
        _mint(alice, address(token));

        uint256 buyEth = 0.01 ether;
        uint256 expected = launchPad.previewBuy(address(token), buyEth);
        vm.prank(bob);
        vm.expectRevert();
        launchPad.buyMeme{value: buyEth}(address(token), expected + 1, _deadline());
    }

    function test_RevertWhen_InvalidPayment() public {
        MemeToken token = _deploy();
        vm.prank(alice);
        vm.expectRevert(LaunchPad.InvalidPayment.selector);
        launchPad.mintMeme{value: PRICE - 1}(address(token));
    }

    function test_RevertWhen_UnknownMeme() public {
        vm.expectRevert(LaunchPad.UnknownMeme.selector);
        launchPad.mintMeme{value: PRICE}(address(0xBEEF));
    }

    function test_RevertWhen_SupplyNotMultipleOfMintUnit() public {
        vm.prank(creator);
        vm.expectRevert(LaunchPad.InvalidSupply.selector);
        launchPad.deployMeme("X", MAX_SUPPLY + 1, PER_MINT, PRICE, GRADUATION_ETH);
    }

    function test_RevertWhen_CannotReachGraduation() public {
        vm.prank(creator);
        vm.expectRevert(LaunchPad.InvalidGraduation.selector);
        launchPad.deployMeme("X", MINT_UNIT, PER_MINT, PRICE, 10 ether);
    }

    function test_RevertWhen_ZeroGraduation() public {
        vm.prank(creator);
        vm.expectRevert(LaunchPad.InvalidGraduation.selector);
        launchPad.deployMeme("X", MAX_SUPPLY, PER_MINT, PRICE, 0);
    }

    function test_LockedEth_StaysUntilGraduate() public {
        MemeToken token = _deploy();
        _mint(alice, address(token));
        assertEq(address(launchPad).balance, _ethForLp() + (PRICE * 100) / 10_000);
    }

    function test_Receive_AcceptsEth() public {
        uint256 amount = 1 ether;
        (bool ok,) = address(launchPad).call{value: amount}("");
        assertTrue(ok);
        assertEq(address(launchPad).balance, amount);
    }

    function test_ManualGraduate_UsesLockedAmounts_ThenAlreadyGraduated() public {
        MemeToken token = _deploy();
        _mint(alice, address(token));
        assertFalse(launchPad.graduated(address(token)));

        // 压低门槛，使已锁仓 ETH 满足毕业条件，从而走手动 graduate（非 mint 自动毕业）
        stdstore.target(address(launchPad)).sig("graduationEth(address)").with_key(address(token)).checked_write(
            uint256(1)
        );

        uint256 ethLp = launchPad.ethRaisedForLp(address(token));
        uint256 memeLp = launchPad.memeReservedForLp(address(token));
        assertEq(ethLp, _ethForLp());
        assertEq(memeLp, _memeForLp());

        launchPad.graduate(address(token), memeLp, ethLp, _deadline());

        assertTrue(launchPad.graduated(address(token)));
        assertEq(launchPad.ethRaisedForLp(address(token)), 0);
        assertEq(launchPad.memeReservedForLp(address(token)), 0);
        assertTrue(launchPad.hasPool(address(token)));

        vm.expectRevert(LaunchPad.AlreadyGraduated.selector);
        launchPad.graduate(address(token), 0, 0, _deadline());
    }

    function test_Graduate_EthRefund_CreditsCreatorPendingFees() public {
        MemeToken token = _deploy();
        _mint(alice, address(token));

        // 先建一个 meme 偏多的池，使后续 addLiquidityETH 按 quote 少用 ETH → Router 退回找零
        uint256 seedMeme = PER_MINT / 2;
        uint256 seedEth = 0.001 ether;
        vm.startPrank(alice);
        token.approve(address(router), seedMeme);
        router.addLiquidityETH{value: seedEth}(address(token), seedMeme, 0, 0, alice, _deadline());
        vm.stopPrank();

        stdstore.target(address(launchPad)).sig("graduationEth(address)").with_key(address(token)).checked_write(
            uint256(1)
        );

        uint256 feesBefore = launchPad.pendingFees(creator);
        uint256 ethLp = launchPad.ethRaisedForLp(address(token));
        uint256 memeLp = launchPad.memeReservedForLp(address(token));
        uint256 padBalBefore = address(launchPad).balance;

        launchPad.graduate(address(token), 0, 0, _deadline());

        uint256 refund = launchPad.pendingFees(creator) - feesBefore;
        assertGt(refund, 0);
        // 找零留在合约内，记入 creator pendingFees；加池用掉 ethLp - refund
        assertEq(address(launchPad).balance, padBalBefore - ethLp + refund);
        assertTrue(launchPad.graduated(address(token)));
        assertEq(memeLp, _memeForLp());
    }

    function test_PreviewMintLockAmounts() public {
        MemeToken token = _deploy();
        (uint256 ethLocked, uint256 memeReserved) = launchPad.previewMintLockAmounts(address(token));
        assertEq(ethLocked, _ethForLp());
        assertEq(memeReserved, _memeForLp());

        vm.expectRevert(LaunchPad.UnknownMeme.selector);
        launchPad.previewMintLockAmounts(address(0xBEEF));
    }
}
