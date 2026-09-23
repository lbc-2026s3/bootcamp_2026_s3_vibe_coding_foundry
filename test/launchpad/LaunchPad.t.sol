// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UniswapV2Factory} from "uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "uniswapv2/UniswapV2Router02.sol";
import {IUniswapV2Pair} from "uniswapv2/interfaces/IUniswapV2Pair.sol";
import {WETH9} from "uniswapv2/WETH9.sol";
import {LaunchPad} from "../../src/launchpad/LaunchPad.sol";
import {MemeToken} from "../../src/launchpad/MemeToken.sol";

/// @dev 拒收 ETH 的 creator，用于验证 pull-fee 不会卡死 mint
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
    LaunchPad internal launchPad;
    UniswapV2Factory internal uniFactory;
    UniswapV2Router02 internal router;
    WETH9 internal weth;

    address internal creator = makeAddr("creator");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    // mintUnit = 1000e18 + 990e18 = 1990e18；须整除 maxSupply
    uint256 internal constant PER_MINT = 1_000e18;
    uint256 internal constant PRICE = 1 ether;
    uint256 internal constant MINT_UNIT = 1_990e18;
    uint256 internal constant MAX_SUPPLY = MINT_UNIT * 100;
    uint256 internal constant GRADUATION_ETH = 100 ether;

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

    function _mintExact(address who, address token) internal {
        (uint256 ethForLp, uint256 memeForLp) = launchPad.previewMintLpAmounts(token);
        vm.prank(who);
        launchPad.mintMeme{value: PRICE}(token, memeForLp, ethForLp, _deadline());
    }

    function test_DeployMeme_SetsPriceAndClone() public {
        MemeToken token = _deploy();

        assertTrue(launchPad.isMeme(address(token)));
        assertEq(token.creator(), creator);
        assertEq(token.symbol(), "DOGE");
        assertEq(token.maxSupply(), MAX_SUPPLY);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.price(), PRICE);
        assertEq(launchPad.graduationEth(address(token)), GRADUATION_ETH);
        assertEq(address(token).code.length, 45);
    }

    function test_MintMeme_CreatorFeePendingAndBurnsLpAtMintPrice() public {
        MemeToken token = _deploy();
        uint256 ethForLp = _ethForLp();
        uint256 memeForLp = _memeForLp();
        uint256 ethForCreator = PRICE - ethForLp;

        _mintExact(alice, address(token));

        assertEq(token.balanceOf(alice), PER_MINT);
        assertEq(creator.balance, 0);
        assertEq(launchPad.pendingFees(creator), ethForCreator);

        vm.prank(creator);
        launchPad.claimFees();
        assertEq(creator.balance, ethForCreator);
        assertEq(launchPad.pendingFees(creator), 0);

        address pair = uniFactory.getPair(address(token), address(weth));
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        (uint256 reserveMeme, uint256 reserveWeth) =
            token0 == address(token) ? (uint256(reserve0), uint256(reserve1)) : (uint256(reserve1), uint256(reserve0));

        assertEq(reserveWeth, ethForLp);
        assertEq(reserveMeme, memeForLp);
        assertGt(IUniswapV2Pair(pair).balanceOf(address(0)), 0);
    }

    function test_BuyMeme_WithAmountOutMin() public {
        MemeToken token = _deploy();
        _mintExact(alice, address(token));

        uint256 buyEth = 0.01 ether;
        uint256 expected = launchPad.previewBuy(address(token), buyEth);

        uint256 before = token.balanceOf(bob);
        vm.prank(bob);
        launchPad.buyMeme{value: buyEth}(address(token), expected, _deadline());
        assertEq(token.balanceOf(bob) - before, expected);
    }

    function test_RevertWhen_BuySlippageTooTight() public {
        MemeToken token = _deploy();
        _mintExact(alice, address(token));

        uint256 buyEth = 0.01 ether;
        uint256 expected = launchPad.previewBuy(address(token), buyEth);
        vm.prank(bob);
        vm.expectRevert();
        launchPad.buyMeme{value: buyEth}(address(token), expected + 1, _deadline());
    }

    function test_SecondMint_AddsLiquidity() public {
        MemeToken token = _deploy();
        _mintExact(alice, address(token));

        address pair = uniFactory.getPair(address(token), address(weth));
        uint256 burnedBefore = IUniswapV2Pair(pair).balanceOf(address(0));

        (uint256 ethForLp, uint256 memeDesired) = launchPad.previewMintLpAmounts(address(token));
        (uint256 reserveMeme, uint256 reserveWeth) = launchPad.getReserves(address(token));
        uint256 memeOptimal = (ethForLp * reserveMeme) / reserveWeth;
        uint256 amountTokenMin = memeOptimal < memeDesired ? memeOptimal : memeDesired;
        uint256 amountETHMin = ethForLp;
        if (memeOptimal > memeDesired) {
            amountETHMin = (memeDesired * reserveWeth) / reserveMeme;
            amountTokenMin = memeDesired;
        }

        vm.prank(bob);
        launchPad.mintMeme{value: PRICE}(address(token), amountTokenMin, amountETHMin, _deadline());

        assertEq(token.balanceOf(bob), PER_MINT);
        assertGt(IUniswapV2Pair(pair).balanceOf(address(0)), burnedBefore);
        assertEq(launchPad.pendingFees(creator), (PRICE * 100) / 10_000 * 2);
    }

    function test_RefundOnlyThisTx_NotDonations() public {
        MemeToken token = _deploy();
        vm.deal(address(launchPad), 1 ether);
        uint256 aliceBefore = alice.balance;

        _mintExact(alice, address(token));

        assertEq(address(launchPad).balance, 1 ether + (PRICE * 100) / 10_000);
        assertLe(aliceBefore - alice.balance, PRICE);
    }

    function test_MintAfterBuy_DoesNotSweepAndStillWorks() public {
        MemeToken token = _deploy();
        _mintExact(alice, address(token));

        uint256 buyEth = 0.05 ether;
        uint256 minOut = launchPad.previewBuy(address(token), buyEth) * 99 / 100;
        vm.prank(bob);
        launchPad.buyMeme{value: buyEth}(address(token), minOut, _deadline());

        // 池价已偏：按当前储备 quote 设 min（与 test_SecondMint 相同）
        (uint256 ethForLp, uint256 memeDesired) = launchPad.previewMintLpAmounts(address(token));
        (uint256 reserveMeme, uint256 reserveWeth) = launchPad.getReserves(address(token));
        uint256 memeOptimal = (ethForLp * reserveMeme) / reserveWeth;
        uint256 amountTokenMin;
        uint256 amountETHMin;
        if (memeOptimal <= memeDesired) {
            amountTokenMin = memeOptimal;
            amountETHMin = ethForLp;
        } else {
            amountTokenMin = memeDesired;
            amountETHMin = (memeDesired * reserveWeth) / reserveMeme;
        }
        // 允许 1% 滑点
        amountTokenMin = amountTokenMin * 99 / 100;
        amountETHMin = amountETHMin * 99 / 100;

        uint256 bobBefore = bob.balance;
        uint256 bobMemeBefore = token.balanceOf(bob);
        vm.prank(bob);
        launchPad.mintMeme{value: PRICE}(address(token), amountTokenMin, amountETHMin, _deadline());
        assertEq(token.balanceOf(bob) - bobMemeBefore, PER_MINT);
        assertLe(bobBefore - bob.balance, PRICE);
    }

    function test_Graduate_ClosesMint() public {
        MemeToken token = _deployWithGraduation(0.99 ether);
        _mintExact(alice, address(token));

        assertTrue(launchPad.graduated(address(token)));

        (uint256 ethForLp, uint256 memeForLp) = launchPad.previewMintLpAmounts(address(token));
        vm.prank(bob);
        vm.expectRevert(LaunchPad.AlreadyGraduated.selector);
        launchPad.mintMeme{value: PRICE}(address(token), memeForLp, ethForLp, _deadline());

        uint256 buyEth = 0.01 ether;
        uint256 expected = launchPad.previewBuy(address(token), buyEth);
        vm.prank(bob);
        launchPad.buyMeme{value: buyEth}(address(token), expected, _deadline());
        assertEq(token.balanceOf(bob), expected);
    }

    function test_RejectEthCreator_MintStillWorks_ViaPullFees() public {
        RejectEthCreator badCreator = new RejectEthCreator();
        vm.prank(address(badCreator));
        MemeToken token =
            MemeToken(launchPad.deployMeme("BAD", MAX_SUPPLY, PER_MINT, PRICE, GRADUATION_ETH));

        _mintExact(alice, address(token));
        assertEq(launchPad.pendingFees(address(badCreator)), (PRICE * 100) / 10_000);

        vm.prank(address(badCreator));
        vm.expectRevert(LaunchPad.EthTransferFailed.selector);
        launchPad.claimFees();
    }

    function test_RevertWhen_Expired() public {
        MemeToken token = _deploy();
        (uint256 ethForLp, uint256 memeForLp) = launchPad.previewMintLpAmounts(address(token));
        vm.prank(alice);
        vm.expectRevert(LaunchPad.Expired.selector);
        launchPad.mintMeme{value: PRICE}(address(token), memeForLp, ethForLp, block.timestamp - 1);
    }

    function test_RevertWhen_InvalidPayment() public {
        MemeToken token = _deploy();
        vm.prank(alice);
        vm.expectRevert(LaunchPad.InvalidPayment.selector);
        launchPad.mintMeme{value: PRICE - 1}(address(token), 0, 0, _deadline());
    }

    function test_RevertWhen_BuyBeforeLiquidity() public {
        MemeToken token = _deploy();
        vm.prank(alice);
        vm.expectRevert();
        launchPad.buyMeme{value: 0.1 ether}(address(token), 0, _deadline());
    }

    function test_RevertWhen_UnknownMeme() public {
        vm.expectRevert(LaunchPad.UnknownMeme.selector);
        launchPad.mintMeme{value: PRICE}(address(0xBEEF), 0, 0, _deadline());
    }

    function test_RevertWhen_SupplyNotMultipleOfMintUnit() public {
        vm.prank(creator);
        vm.expectRevert(LaunchPad.InvalidSupply.selector);
        launchPad.deployMeme("X", MAX_SUPPLY + 1, PER_MINT, PRICE, GRADUATION_ETH);
    }

    function test_RevertWhen_SupplyTooSmallForLiquidity() public {
        vm.prank(creator);
        vm.expectRevert(LaunchPad.InvalidSupply.selector);
        launchPad.deployMeme("X", PER_MINT, PER_MINT, PRICE, GRADUATION_ETH);
    }

    function test_RevertWhen_ZeroGraduation() public {
        vm.prank(creator);
        vm.expectRevert(LaunchPad.InvalidGraduation.selector);
        launchPad.deployMeme("X", MAX_SUPPLY, PER_MINT, PRICE, 0);
    }
}
