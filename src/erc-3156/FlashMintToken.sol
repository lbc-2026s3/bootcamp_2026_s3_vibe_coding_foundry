// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";

/// @notice 可闪电增发的 ERC20。`flashLoan` 铸造本金，回调结束后烧掉；手续费从借款人余额划给 `feeReceiver`。
/// @dev `mint` 无权限，只给本地测试准备手续费。不要部署到主网。
contract FlashMintToken is ERC20, ERC20FlashMint {
    /// @dev 手续费 = amount * FEE_BPS / 10_000，即 0.10%。不足 1 wei 时手续费为 0。
    uint256 public constant FEE_BPS = 10;
    uint256 private constant _BPS = 10_000;

    address private immutable _feeReceiver;

    error ZeroAddress();

    constructor(address feeReceiver_) ERC20("Flash Mint Token", "FMT") {
        if (feeReceiver_ == address(0)) revert ZeroAddress();
        _feeReceiver = feeReceiver_;
    }

    function feeReceiver() public view returns (address) {
        return _feeReceiver;
    }

    /// @notice 演示用增发。闪电贷本金不走这里，只用来给借款人准备手续费。
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _flashFee(address, uint256 value) internal pure override returns (uint256) {
        return (value * FEE_BPS) / _BPS;
    }

    function _flashFeeReceiver() internal view override returns (address) {
        return _feeReceiver;
    }
}
