// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title WrappedToken — 目标链包装币（trusted relayer lock-and-mint）
/// @notice relayer 看见源链 `Locked` 后 `mint`；用户 `burn` 发出销毁事件，relayer 再去源链 `release`。
/// @dev 只有 relayer 能 mint。用户烧币不需要 relayer，但若 relayer 不去源链 `release`，原币会一直锁着。
///      包装币 18 decimals，与 `CanonicalToken` 1:1。本 demo 不处理跨链 decimals 漂移。
contract WrappedToken is ERC20, Ownable, ReentrancyGuard {
    /// @notice 本端逻辑域（包装币所在域）。
    uint64 public immutable i_localDomain;
    /// @notice 对端逻辑域（原币金库所在域）。
    uint64 public immutable i_peerDomain;

    /// @notice 唯一被授权 `mint` 的搬运工。
    address public s_relayer;
    /// @notice 下一笔 `burn` 将使用的 nonce（从 1 起）。
    uint64 public s_nonce;
    /// @notice 已处理的源链锁仓消息，防重放铸币。
    mapping(bytes32 messageId => bool processed) public s_processed;

    event Minted(
        bytes32 indexed messageId,
        uint64 indexed srcDomain,
        uint64 destDomain,
        uint64 nonce,
        address sender,
        address recipient,
        uint256 amount
    );
    event Burned(
        bytes32 indexed messageId,
        uint64 indexed srcDomain,
        uint64 destDomain,
        uint64 nonce,
        address sender,
        address recipient,
        uint256 amount
    );
    event RelayerUpdated(address indexed previousRelayer, address indexed newRelayer);

    error ZeroAmount();
    error ZeroAddress();
    error ZeroRelayer();
    error InvalidDomain();
    error SameDomain();
    error NotRelayer();
    error UnknownSourceDomain(uint64 srcDomain);
    error InvalidDestDomain(uint64 destDomain);
    error AlreadyProcessed(bytes32 messageId);

    modifier onlyRelayer() {
        if (msg.sender != s_relayer) revert NotRelayer();
        _;
    }

    /// @param localDomain 本端逻辑域（例如 2）
    /// @param peerDomain 对端逻辑域（例如 1）
    /// @param relayer 初始 relayer
    /// @param owner 可更换 relayer 的 owner
    constructor(uint64 localDomain, uint64 peerDomain, address relayer, address owner)
        ERC20("Wrapped Canonical Token", "wCANON")
        Ownable(owner)
    {
        if (localDomain == 0 || peerDomain == 0) revert InvalidDomain();
        if (localDomain == peerDomain) revert SameDomain();
        if (relayer == address(0)) revert ZeroRelayer();

        i_localDomain = localDomain;
        i_peerDomain = peerDomain;
        s_relayer = relayer;
        emit RelayerUpdated(address(0), relayer);
    }

    /// @notice relayer 提交源链锁仓消息后，给 `recipient` 铸造包装币。
    function mint(
        uint64 srcDomain,
        uint64 destDomain,
        uint64 nonce,
        address sender,
        address recipient,
        uint256 amount
    ) external nonReentrant onlyRelayer {
        if (srcDomain != i_peerDomain) revert UnknownSourceDomain(srcDomain);
        if (destDomain != i_localDomain) revert InvalidDestDomain(destDomain);
        if (sender == address(0) || recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        bytes32 messageId = computeMessageId(srcDomain, destDomain, nonce, sender, recipient, amount);
        if (s_processed[messageId]) revert AlreadyProcessed(messageId);

        s_processed[messageId] = true;
        emit Minted(messageId, srcDomain, destDomain, nonce, sender, recipient, amount);
        _mint(recipient, amount);
    }

    /// @notice 销毁调用者持有的包装币，发出「请在源链解锁给 recipient」事件。
    /// @dev 烧币立刻生效；源链解锁完全依赖 relayer 去调 `LockVault.release`。
    function burn(uint256 amount, address recipientOnHome) external nonReentrant returns (bytes32 messageId) {
        if (recipientOnHome == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint64 nonce = ++s_nonce;
        messageId = computeMessageId(i_localDomain, i_peerDomain, nonce, msg.sender, recipientOnHome, amount);

        emit Burned(messageId, i_localDomain, i_peerDomain, nonce, msg.sender, recipientOnHome, amount);
        _burn(msg.sender, amount);
    }

    /// @notice 更换搬运工。
    function setRelayer(address newRelayer) external onlyOwner {
        if (newRelayer == address(0)) revert ZeroRelayer();
        address previous = s_relayer;
        s_relayer = newRelayer;
        emit RelayerUpdated(previous, newRelayer);
    }

    /// @notice 与对端 `LockVault` 使用同一套编码，才能对得上 `messageId`。
    function computeMessageId(
        uint64 srcDomain,
        uint64 destDomain,
        uint64 nonce,
        address sender,
        address recipient,
        uint256 amount
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(srcDomain, destDomain, nonce, sender, recipient, amount));
    }
}
