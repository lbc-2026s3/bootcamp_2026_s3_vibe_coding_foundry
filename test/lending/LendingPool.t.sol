// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockERC20} from "../../src/lending/MockERC20.sol";
import {JumpRateModel} from "../../src/lending/JumpRateModel.sol";
import {SimplePriceOracle} from "../../src/lending/SimplePriceOracle.sol";
import {LendingPool} from "../../src/lending/LendingPool.sol";

contract LendingPoolTest is Test {
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    MockERC20 internal collateral;
    MockERC20 internal borrowAsset;
    SimplePriceOracle internal oracle;
    JumpRateModel internal model;
    LendingPool internal pool;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal liquidator = makeAddr("liquidator");

    function setUp() public {
        collateral = new MockERC20("Wrapped Ether", "WETH");
        borrowAsset = new MockERC20("USD Coin", "USDC");
        oracle = new SimplePriceOracle(address(this));
        oracle.setPrice(address(collateral), 2000e18);
        oracle.setPrice(address(borrowAsset), 1e18);
        model = new JumpRateModel(
            0.02e18 / SECONDS_PER_YEAR, 0.10e18 / SECONDS_PER_YEAR, 4.5e18 / SECONDS_PER_YEAR, 0.80e18
        );
        pool = new LendingPool(
            collateral, borrowAsset, oracle, model, 0.75e18, 1.08e18, 0.50e18, 0.10e18, address(this)
        );
    }

    function _deposit(address user, uint256 assets) internal {
        borrowAsset.mint(user, assets);
        vm.startPrank(user);
        borrowAsset.approve(address(pool), assets);
        pool.deposit(assets);
        vm.stopPrank();
    }

    function _openBorrow(address lender, address borrower, uint256 supplied, uint256 collateralAmount, uint256 borrowed)
        internal
    {
        _deposit(lender, supplied);
        collateral.mint(borrower, collateralAmount);
        vm.startPrank(borrower);
        collateral.approve(address(pool), collateralAmount);
        pool.depositCollateral(collateralAmount);
        if (borrowed > 0) pool.borrow(borrowed);
        vm.stopPrank();
    }

    function test_depositMintsOneToOneOnEmptyPool() public {
        _deposit(alice, 1_000e18);

        assertEq(pool.sharesOf(alice), 1_000e18);
        assertEq(pool.totalShares(), 1_000e18);
        assertEq(pool.exchangeRate(), 1e18);
        assertEq(pool.cash(), 1_000e18);
        assertEq(pool.borrowIndex(), 1e18);
    }

    function test_withdrawReturnsAssets() public {
        _deposit(alice, 1_000e18);

        vm.prank(alice);
        pool.withdraw(400e18);

        assertEq(borrowAsset.balanceOf(alice), 400e18);
        assertEq(pool.sharesOf(alice), 600e18);
        assertEq(pool.cash(), 600e18);
    }

    function test_withdrawRevertsWithoutShares() public {
        _deposit(alice, 100e18);

        vm.prank(bob);
        vm.expectRevert(LendingPool.InsufficientShares.selector);
        pool.withdraw(1);
    }

    function test_identicalTokensRevert() public {
        vm.expectRevert(LendingPool.IdenticalTokens.selector);
        new LendingPool(borrowAsset, borrowAsset, oracle, model, 0.75e18, 1.08e18, 0.50e18, 0.10e18, address(this));
    }

    function test_borrowAtCollateralFactorSucceedsAndOneWeiReverts() public {
        _deposit(alice, 2_000e18);
        collateral.mint(bob, 1e18);
        vm.startPrank(bob);
        collateral.approve(address(pool), 1e18);
        pool.depositCollateral(1e18);
        pool.borrow(1_500e18);
        vm.expectRevert(LendingPool.Unhealthy.selector);
        pool.borrow(1);
        vm.stopPrank();

        assertEq(pool.borrowBalanceStored(bob), 1_500e18);
        assertEq(borrowAsset.balanceOf(bob), 1_500e18);
    }

    function test_withdrawCollateralThatBreaksHealthReverts() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);

        vm.prank(bob);
        vm.expectRevert(LendingPool.Unhealthy.selector);
        pool.withdrawCollateral(0.5e18);
    }

    function test_repayReducesDebt() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);
        borrowAsset.mint(carol, 100e18);

        vm.startPrank(carol);
        borrowAsset.approve(address(pool), 100e18);
        pool.repay(bob, 100e18);
        vm.stopPrank();

        assertEq(pool.borrowBalanceStored(bob), 700e18);
        assertEq(pool.totalBorrows(), 700e18);
    }

    function test_repayAllWithMaxUint() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);

        vm.startPrank(bob);
        borrowAsset.approve(address(pool), type(uint256).max);
        pool.repay(bob, type(uint256).max);
        vm.stopPrank();

        assertEq(pool.borrowBalanceStored(bob), 0);
        assertEq(pool.principalOf(bob), 0);
        assertEq(pool.totalBorrows(), 0);
    }

    function test_repayAboveDebtReverts() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);

        vm.startPrank(bob);
        borrowAsset.approve(address(pool), type(uint256).max);
        vm.expectRevert(LendingPool.RepayExceedsDebt.selector);
        pool.repay(bob, 800e18 + 1);
        vm.stopPrank();
    }

    function test_withdrawRevertsWhenCashInsufficient() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);

        vm.prank(alice);
        vm.expectRevert(LendingPool.InsufficientCash.selector);
        pool.withdraw(1_000e18);
    }

    function test_interestIncreasesDebtReservesAndExchangeRate() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);
        uint256 rate = model.getBorrowRate(pool.cash(), pool.totalBorrows(), pool.totalReserves());

        vm.warp(block.timestamp + SECONDS_PER_YEAR);
        uint256 interest = 800e18 * rate * SECONDS_PER_YEAR / 1e18;
        pool.accrueInterest();

        assertEq(pool.totalBorrows(), 800e18 + interest);
        assertEq(pool.borrowBalanceStored(bob), 800e18 + interest);
        assertEq(pool.totalReserves(), interest * 0.10e18 / 1e18);
        assertGt(pool.exchangeRate(), 1e18);
    }

    function test_laterDepositorReceivesFewerSharesAfterInterest() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);
        vm.warp(block.timestamp + SECONDS_PER_YEAR);
        pool.accrueInterest();

        _deposit(carol, 1_000e18);

        assertEq(pool.sharesOf(alice), 1_000e18);
        assertLt(pool.sharesOf(carol), 1_000e18);
    }

    function test_indexGrowsFasterAboveKink() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);

        LendingPool high = new LendingPool(
            collateral, borrowAsset, oracle, model, 0.75e18, 1.08e18, 0.50e18, 0.10e18, address(this)
        );
        borrowAsset.mint(alice, 1_000e18);
        vm.startPrank(alice);
        borrowAsset.approve(address(high), 1_000e18);
        high.deposit(1_000e18);
        vm.stopPrank();
        collateral.mint(bob, 1e18);
        vm.startPrank(bob);
        collateral.approve(address(high), 1e18);
        high.depositCollateral(1e18);
        high.borrow(900e18);
        vm.stopPrank();

        vm.warp(block.timestamp + SECONDS_PER_YEAR);
        pool.accrueInterest();
        high.accrueInterest();

        assertGt(high.borrowIndex() - 1e18, pool.borrowIndex() - 1e18);
    }

    function test_liquidateRevertsWhenHealthy() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);
        borrowAsset.mint(liquidator, 400e18);

        vm.startPrank(liquidator);
        borrowAsset.approve(address(pool), 400e18);
        vm.expectRevert(LendingPool.NoShortfall.selector);
        pool.liquidate(bob, 400e18);
        vm.stopPrank();
    }

    function test_liquidateSeizesBonusCollateral() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);
        oracle.setPrice(address(collateral), 500e18);
        borrowAsset.mint(liquidator, 400e18);

        vm.startPrank(liquidator);
        borrowAsset.approve(address(pool), 400e18);
        pool.liquidate(bob, 400e18);
        vm.stopPrank();

        assertEq(pool.borrowBalanceStored(bob), 400e18);
        assertEq(pool.collateralOf(bob), 1e18 - 0.864e18);
        assertEq(collateral.balanceOf(liquidator), 0.864e18);
        assertEq(pool.totalBorrows(), 400e18);
    }

    function test_liquidateRevertsAboveCloseFactor() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);
        oracle.setPrice(address(collateral), 500e18);
        borrowAsset.mint(liquidator, 400e18 + 1);

        vm.startPrank(liquidator);
        borrowAsset.approve(address(pool), 400e18 + 1);
        vm.expectRevert(LendingPool.RepayExceedsCloseFactor.selector);
        pool.liquidate(bob, 400e18 + 1);
        vm.stopPrank();
    }

    function test_fullCloseRevertsWhenSeizeExceedsCollateralButSmallerRepayWorks() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);
        oracle.setPrice(address(collateral), 100e18);
        borrowAsset.mint(liquidator, 400e18);

        vm.startPrank(liquidator);
        borrowAsset.approve(address(pool), 400e18);
        vm.expectRevert(LendingPool.SeizeExceedsCollateral.selector);
        pool.liquidate(bob, 400e18);

        pool.liquidate(bob, 90e18);
        vm.stopPrank();

        assertEq(pool.borrowBalanceStored(bob), 710e18);
        assertEq(collateral.balanceOf(liquidator), 0.972e18);
    }

    function test_reduceReservesPaysOwnerWithoutChangingExchangeRate() public {
        _openBorrow(alice, bob, 1_000e18, 1e18, 800e18);
        vm.warp(block.timestamp + SECONDS_PER_YEAR);
        pool.accrueInterest();

        uint256 reserves = pool.totalReserves();
        uint256 rateBefore = pool.exchangeRate();
        uint256 ownerBefore = borrowAsset.balanceOf(address(this));

        pool.reduceReserves(reserves);

        assertEq(pool.totalReserves(), 0);
        assertEq(pool.exchangeRate(), rateBefore);
        assertEq(borrowAsset.balanceOf(address(this)), ownerBefore + reserves);
    }

    function test_nonOwnerCannotReduceReserves() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        pool.reduceReserves(1);
    }
}
