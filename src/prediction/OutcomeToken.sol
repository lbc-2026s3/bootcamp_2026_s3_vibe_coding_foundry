// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice 预测市场结果份额；仅所属 market 可 mint/burn。
contract OutcomeToken is ERC20 {
    address public immutable market;
    uint8 private immutable _decimals;

    error NotMarket();
    error ZeroAddress();

    modifier onlyMarket() {
        if (msg.sender != market) revert NotMarket();
        _;
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_, address market_)
        ERC20(name_, symbol_)
    {
        if (market_ == address(0)) revert ZeroAddress();
        market = market_;
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice 铸造份额给 `to`（仅 market）。
    function mint(address to, uint256 amount) external onlyMarket {
        _mint(to, amount);
    }

    /// @notice 从 `from` 销毁份额（仅 market）。
    function burn(address from, uint256 amount) external onlyMarket {
        _burn(from, amount);
    }
}
