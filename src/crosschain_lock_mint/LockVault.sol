// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title LockVault — 源链锁仓 / 解锁（trusted relayer lock-and-mint）
/// @notice 用户 `lock` 把原币锁进金库并发出事件；relayer 看见对端 `Burned` 后再调 `release` 解锁。
/// @dev 本合约**不能**自己去对端铸币。没人当 relayer 调用对端，包装币永远不会出现。
///      信任模型：relayer 等价于中心化预言机。它不能用假 `release` 掏走超过真实锁仓的原币
///      （`s_locked` 上限），但仍可在对端凭空 `mint` 包装币——这就是 trusted relayer 的边界。
contract LockVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice 被锁仓的原币（源链 canonical token）。
    IERC20 public immutable i_token;
    /// @notice 本端逻辑域。单链测试里用构造函数注入，不要用 `block.chainid`。
    uint64 public immutable i_localDomain;
    /// @notice 对端逻辑域（包装币所在域）。
    uint64 public immutable i_peerDomain;

    /// @notice 唯一被授权在本端 `release` 的搬运工。
    address public s_relayer;
    /// @notice 下一笔 `lock` 将使用的 nonce（从 1 起）。
    uint64 public s_nonce;
    /// @notice 仍锁在金库、尚未 `release` 的数量。
    uint256 public s_locked;
    /// @notice 已处理的对端销毁消息，防重放。
    mapping(bytes32 messageId => bool processed) public s_processed;

    event Locked(
        bytes32 indexed messageId,
        uint64 indexed srcDomain,
        uint64 destDomain,
        uint64 nonce,
        address sender,
        address recipient,
        uint256 amount
    );
    event Released(
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
    error InsufficientLocked(uint256 locked, uint256 amount);

    modifier onlyRelayer() {
        if (msg.sender != s_relayer) revert NotRelayer();
        _;
    }

    /// @param token 源链原币
    /// @param localDomain 本端逻辑域（例如 1）
    /// @param peerDomain 对端逻辑域（例如 2）
    /// @param relayer 初始 relayer
    /// @param owner 可更换 relayer 的 owner
    constructor(IERC20 token, uint64 localDomain, uint64 peerDomain, address relayer, address owner)
        Ownable(owner)
    {
        if (address(token) == address(0)) revert ZeroAddress();
        if (localDomain == 0 || peerDomain == 0) revert InvalidDomain();
        if (localDomain == peerDomain) revert SameDomain();
        if (relayer == address(0)) revert ZeroRelayer();

        i_token = token;
        i_localDomain = localDomain;
        i_peerDomain = peerDomain;
        s_relayer = relayer;
        emit RelayerUpdated(address(0), relayer);
    }

    /// @notice 锁仓并把「请在对端铸造」写进事件。调用前需 `approve` 本合约。
    /// @dev 无人读事件并去对端 `mint` 时，代币只是锁在这里，对端余额不变。
    // @param recipient 接收者，目标链上谁该拿到包装币
    // @param amount 金额，源链上锁仓的金额
    // @return messageId 消息ID
    function lock(address recipient, uint256 amount) external nonReentrant returns (bytes32 messageId) {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint64 nonce = ++s_nonce;
        messageId = computeMessageId(i_localDomain, i_peerDomain, nonce, msg.sender, recipient, amount);
        s_locked += amount;

        emit Locked(messageId, i_localDomain, i_peerDomain, nonce, msg.sender, recipient, amount);
        i_token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice relayer 提交对端销毁消息后，把原币释放给 `recipient`。
    /// @dev Checks-Effects-Interactions：先标记 processed / 扣 `s_locked`，再转账。
    function release(
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
        if (s_locked < amount) revert InsufficientLocked(s_locked, amount);

        s_processed[messageId] = true;
        s_locked -= amount;

        emit Released(messageId, srcDomain, destDomain, nonce, sender, recipient, amount);
        i_token.safeTransfer(recipient, amount);
    }

    /// @notice 更换搬运工。生产环境应把 owner 交给 multisig；本 demo 方便测试切换 relayer。
    function setRelayer(address newRelayer) external onlyOwner {
        if (newRelayer == address(0)) revert ZeroRelayer();
        address previous = s_relayer;
        s_relayer = newRelayer;
        emit RelayerUpdated(previous, newRelayer);
    }

    /// @notice 与对端 `WrappedToken` 使用同一套编码，才能对得上 `messageId`。
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
