// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @notice 可被 EIP-1167 最小代理克隆的 Meme ERC-20。
/// @dev 实现合约的 constructor 会锁住 initialize;克隆合约走 initialize 写入各自的 symbol / 上限。
///      `factory` 是 immutable,写在实现合约 bytecode 里,所有克隆共享同一工厂地址。
contract MemeToken is ERC20 {
    error AlreadyInitialized();
    error NotFactory();
    error CapExceeded();

    /// @dev 必须是 immutable,不能放 storage。
    ///      clone 不跑 constructor,delegatecall 执行的是实现合约代码;
    ///      immutable 编进实现合约 bytecode,所有 clone 读到同一个 factory。
    ///      若写成 storage,constructor 只写实现合约自己的 slot,clone 上该槽是 address(0),onlyFactory 会把 mint 全拒掉。
    address public immutable factory;

    address public creator;
    uint256 public maxSupply;
    uint256 public perMint;

    string private _memeSymbol;
    bool private _initialized;

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    constructor(address factory_) ERC20("", "") {
        factory = factory_;
        _initialized = true;
    }

    function initialize(address creator_, string memory symbol_, uint256 maxSupply_, uint256 perMint_)
        external
        onlyFactory
    {
        if (_initialized) revert AlreadyInitialized();

        _initialized = true;
        creator = creator_;
        _memeSymbol = symbol_;
        maxSupply = maxSupply_;
        perMint = perMint_;
    }

    function name() public view override returns (string memory) {
        return _memeSymbol;
    }

    function symbol() public view override returns (string memory) {
        return _memeSymbol;
    }

    /// @notice 由工厂调用,向 `to` 铸造 `perMint` 枚。剩余额度不足一次铸造时回退。
    function mint(address to) external onlyFactory {
        uint256 amount = perMint;
        uint256 supply = totalSupply();
        if (supply >= maxSupply || maxSupply - supply < amount) revert CapExceeded();
        _mint(to, amount);
    }
}
