// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import {FlashMintToken} from "../../src/erc-3156/FlashMintToken.sol";
import {SimpleFlashBorrower} from "../../src/erc-3156/SimpleFlashBorrower.sol";

contract FlashMintTest is Test {
    FlashMintToken public token;
    SimpleFlashBorrower public borrower;

    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");

    uint256 constant BORROW_AMOUNT = 1_000 ether;

    function setUp() public {
        token = new FlashMintToken(treasury);
        borrower = new SimpleFlashBorrower(IERC3156FlashLender(address(token)));
    }

    function _fee(uint256 amount) internal view returns (uint256) {
        return token.flashFee(address(token), amount);
    }

    function _fundFee(uint256 amount) internal {
        token.mint(address(borrower), _fee(amount));
    }

    function test_flashLoanBurnsPrincipalAndPaysFee() public {
        uint256 fee = _fee(BORROW_AMOUNT);
        _fundFee(BORROW_AMOUNT);
        uint256 supplyBefore = token.totalSupply();

        borrower.flashBorrow(BORROW_AMOUNT);

        assertEq(fee, BORROW_AMOUNT * token.FEE_BPS() / 10_000);
        assertEq(borrower.borrowCount(), 1);
        assertEq(borrower.balanceDuringLoan(), fee + BORROW_AMOUNT);
        assertEq(borrower.supplyDuringLoan(), supplyBefore + BORROW_AMOUNT);
        assertEq(token.totalSupply(), supplyBefore);
        assertEq(token.balanceOf(address(borrower)), 0);
        assertEq(token.balanceOf(treasury), fee);
        assertEq(token.allowance(address(borrower), address(token)), 0);
    }

    function test_maxFlashLoanAndUnsupportedToken() public {
        assertEq(token.maxFlashLoan(address(token)), type(uint256).max);
        assertEq(token.maxFlashLoan(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(ERC20FlashMint.ERC3156UnsupportedToken.selector, alice));
        token.flashFee(alice, BORROW_AMOUNT);
    }

    function test_revertsWhenLoanExceedsMax() public {
        token.mint(alice, 1 ether);
        uint256 maxLoan = token.maxFlashLoan(address(token));

        vm.expectRevert(abi.encodeWithSelector(ERC20FlashMint.ERC3156ExceededMaxLoan.selector, maxLoan));
        token.flashLoan(IERC3156FlashBorrower(address(borrower)), address(token), maxLoan + 1, "");
    }

    function test_revertsWhenFeeBalanceMissing() public {
        uint256 fee = _fee(BORROW_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(borrower), 0, fee)
        );
        borrower.flashBorrow(BORROW_AMOUNT);

        assertEq(token.totalSupply(), 0);
        assertEq(borrower.borrowCount(), 0);
    }

    function test_revertsWhenInitiatorIsNotBorrower() public {
        _fundFee(BORROW_AMOUNT);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SimpleFlashBorrower.NotSelfInitiated.selector, alice));
        token.flashLoan(IERC3156FlashBorrower(address(borrower)), address(token), BORROW_AMOUNT, "");

        assertEq(token.balanceOf(address(borrower)), _fee(BORROW_AMOUNT));
        assertEq(token.balanceOf(treasury), 0);
        assertEq(borrower.borrowCount(), 0);
    }
}
