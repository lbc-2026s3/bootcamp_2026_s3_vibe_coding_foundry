// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @notice LaunchPad 用的可克隆 Meme ERC-20。
/// @dev `factory` 为 immutable（进实现合约 bytecode），所有 clone 共享同一 LaunchPad 地址。
contract MemeToken is ERC20 {
    error AlreadyInitialized();
    error NotFactory();
    error CapExceeded();
    error ZeroAmount();

    address public immutable factory;

    address public creator;
    uint256 public maxSupply;
    uint256 public perMint;
    /// @notice 每次 `mintMeme` 需支付的 ETH（wei），对应铸造 `perMint` 枚。
    /// @dev 单价（wei/枚）= `price / perMint`；例：price=1 ether、perMint=1000e18 → 0.001 ether/枚。
    uint256 public price;

    string private _memeSymbol;
    bool private _initialized;

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    constructor(address factory_) ERC20("", "") {
        factory = factory_;
        // 锁住实现合约本身：clone 不跑 constructor，其 _initialized 仍为 false，可走 initialize
        _initialized = true;
    }

    function initialize(
        address creator_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 perMint_,
        uint256 price_
    ) external onlyFactory {
        if (_initialized) revert AlreadyInitialized();

        // 每个 clone 只允许初始化一次
        _initialized = true;
        creator = creator_;
        _memeSymbol = symbol_;
        maxSupply = maxSupply_;
        perMint = perMint_;
        price = price_;
    }

    function name() public view override returns (string memory) {
        return _memeSymbol;
    }

    function symbol() public view override returns (string memory) {
        return _memeSymbol;
    }

    /// @notice 由 LaunchPad 铸造任意数量，不超过 `maxSupply`。
    function mint(address to, uint256 amount) external onlyFactory {
        if (amount == 0) revert ZeroAmount();
        uint256 supply = totalSupply();
        if (supply >= maxSupply || maxSupply - supply < amount) revert CapExceeded();
        _mint(to, amount);
    }
}
