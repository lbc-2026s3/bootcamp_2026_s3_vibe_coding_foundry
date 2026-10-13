// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice 练习用稳定币。往 mint 里附带 ETH 才会铸出代币，1 ETH 换 1 mUSDT。
///         这不是以太坊主网上的官方 USDT。
contract MyUSDT is ERC20, ERC20Pausable, Ownable, ReentrancyGuard {
    /// @notice 1 枚代币 = 10^6 个最小单位，1 ETH = 10^18 wei，所以 1 枚代币对应 10^12 wei。
    uint256 public constant WEI_PER_TOKEN = 1e12;

    event Mint(address indexed to, uint256 amount, uint256 reserveAmount);
    event Burn(address indexed from, uint256 amount, uint256 reserveAmount);

    constructor() ERC20("My USDT", "mUSDT") Ownable(msg.sender) {}

    /// @notice 和官方 USDT 一样，显示精度是 6。链上的 1000000 才等于 1 枚。
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice 合约里锁着的 ETH。每铸出 1 枚代币，这里就多 1 ETH。
    function totalReserves() public view returns (uint256) {
        return address(this).balance;
    }

    /// @notice 调用时附带 ETH。不足 0.000001 ETH 铸不出 1 个最小单位，整笔会失败。
    ///         多出来、换不成整枚的零头会退回。
    function mint(address to) external payable nonReentrant {
        uint256 amount = msg.value / WEI_PER_TOKEN;
        require(amount > 0, "Need at least 0.000001 ETH");

        uint256 used = amount * WEI_PER_TOKEN;
        uint256 dust = msg.value - used;

        _mint(to, amount);
        emit Mint(to, amount, used);

        if (dust > 0) {
            (bool ok,) = msg.sender.call{value: dust}("");
            require(ok, "Dust refund failed");
        }
    }

    /// @notice 烧掉自己的代币，按同样汇率拿回 ETH。
    function burn(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        _burn(msg.sender, amount);

        uint256 ethOut = amount * WEI_PER_TOKEN;
        emit Burn(msg.sender, amount, ethOut);

        (bool ok,) = msg.sender.call{value: ethOut}("");
        require(ok, "ETH transfer failed");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
