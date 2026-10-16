// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title SocialRecoveryWallet — 社交恢复钱包
/// @notice 日常只有一把钥匙。守护者平时动不了钱，只在这把钥匙丢了的时候，
///         一起指定一个新主人。和多签的差别是：转账不需要每次都凑签名。
///
///         1. 空闲：只有 `owner` 能 `execute`。
///         2. 收集：任意一名守护者 `initiateRecovery`，其他守护者 `confirmRecovery`。
///            这一步开始，钱包锁上，旧钥匙不能转账，也不能换守护者。
///         3. 等待：确认数达到 `threshold` 时，记下 `executableAt = now + securityPeriod`。
///            主人还没换。这段时间里，还拿着旧钥匙的人可以 `cancelRecovery`。
///         4. 生效：`executableAt` 到了以后，任何人调用 `executeRecovery`，`owner` 才换成新人。
///            合约自己不会到点执行。
/// @dev 安全期防的是「守护者串通、主人钥匙还在」。钥匙已经被偷走时，小偷就是当前主人，
///      他可以取消恢复再把钱转走。社交恢复解决的是钥匙丢失，不是钥匙被盗。
contract SocialRecoveryWallet is ReentrancyGuard {
    enum Phase {
        Idle, // 没有进行中的恢复，主人可以转账
        Collecting, // 已发起，确认数还不够，钱包已锁
        Waiting, // 确认数已够，安全期还没结束
        Ready // 安全期已结束，任何人都可以执行恢复
    }

    struct Recovery {
        /// @notice 这一轮要换成的新主人。`address(0)` 表示没有进行中的恢复。
        address proposedOwner;
        /// @notice 已经同意的守护者人数，发起人算第一票。
        uint256 confirmations;
        /// @notice 最早可以换主人的时间戳。确认数还没到 `threshold` 时是 0；
        ///         达标后写成 `block.timestamp + securityPeriod`，到点之前主人不变。
        uint256 executableAt;
    }

    /// @notice 守护者人数上限。确认和清理都要遍历，名单必须短。
    uint256 public constant MAX_GUARDIANS = 16;

    address public owner;
    uint256 public immutable threshold;
    /// @notice 确认数达标之后，还要再等这么久才能换主人。
    uint256 public immutable securityPeriod;

    address[] public guardians;
    mapping(address account => bool) public isGuardian;

    /// @notice 当前这一轮恢复。`proposedOwner == address(0)` 表示没有进行中的恢复。
    Recovery public pendingRecovery;
    /// @notice 守护者是否已对当前这一轮投过票。发起人算已确认。
    mapping(address guardian => bool) public hasConfirmed;

    event Deposit(address indexed sender, uint256 amount);
    event Executed(address indexed owner, address indexed to, uint256 value, bytes data);
    event GuardiansReplaced(address indexed owner, address[] guardians);
    event RecoveryInitiated(address indexed proposedOwner, address indexed guardian);
    event RecoveryConfirmed(address indexed guardian, uint256 confirmations);
    event RecoveryReady(address indexed proposedOwner, uint256 executableAt);
    event RecoveryCancelled(address indexed proposedOwner, address indexed owner);
    event RecoveryExecuted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner(address caller);
    error NotGuardian(address caller);
    error InvalidOwner();
    error InvalidGuardians();
    error InvalidThreshold(uint256 threshold, uint256 guardianCount);
    error InvalidSecurityPeriod();
    error InvalidNewOwner(address newOwner);
    error RecoveryInProgress();
    error NoActiveRecovery();
    error RecoveryAlreadyReady(uint256 executableAt);
    error AlreadyConfirmed(address guardian);
    error RecoveryNotReady();
    error SecurityPeriodActive(uint256 executableAt);
    error ExecutionFailed();

    /// @param _owner 日常签名的那把钥匙
    /// @param _guardians 丢钥匙时可以发起恢复的地址。不能包含主人和重复地址
    /// @param _threshold 至少几名守护者同意才进入安全期
    /// @param _securityPeriod 进入安全期后再等多久才允许换主人，不能为 0
    constructor(address _owner, address[] memory _guardians, uint256 _threshold, uint256 _securityPeriod) payable {
        if (_owner == address(0)) revert InvalidOwner();
        if (_securityPeriod == 0) revert InvalidSecurityPeriod();

        owner = _owner;
        securityPeriod = _securityPeriod;
        _setGuardians(_guardians);

        if (_threshold == 0 || _threshold > _guardians.length) {
            revert InvalidThreshold(_threshold, _guardians.length);
        }
        threshold = _threshold;

        emit OwnershipTransferred(address(0), _owner);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice 主人转出 ETH 或调用别的合约。有进行中的恢复时会失败。
    function execute(address to, uint256 value, bytes calldata data) external nonReentrant {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        if (pendingRecovery.proposedOwner != address(0)) revert RecoveryInProgress();

        emit Executed(msg.sender, to, value, data);

        (bool ok,) = to.call{value: value}(data);
        if (!ok) revert ExecutionFailed();
    }

    /// @notice 主人更换整份守护者名单。恢复进行中时不能换，避免把正在投票的人换掉。
    function replaceGuardians(address[] calldata next) external {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        if (pendingRecovery.proposedOwner != address(0)) revert RecoveryInProgress();
        if (next.length < threshold) revert InvalidThreshold(threshold, next.length);

        _setGuardians(next);
        emit GuardiansReplaced(msg.sender, next);
    }

    /// @notice 守护者发起恢复。发起人算第一票。已有一轮恢复时不能再开一轮。
    function initiateRecovery(address newOwner) external {
        if (!isGuardian[msg.sender]) revert NotGuardian(msg.sender);
        if (pendingRecovery.proposedOwner != address(0)) revert RecoveryInProgress();
        if (newOwner == address(0) || newOwner == owner) revert InvalidNewOwner(newOwner);

        pendingRecovery.proposedOwner = newOwner;
        pendingRecovery.confirmations = 1;
        hasConfirmed[msg.sender] = true;

        emit RecoveryInitiated(newOwner, msg.sender);
        emit RecoveryConfirmed(msg.sender, 1);

        if (threshold == 1) _markReady();
    }

    /// @notice 其他守护者同意这一轮恢复。凑满 `threshold` 后进入安全期，此时还不换主人。
    function confirmRecovery() external {
        if (!isGuardian[msg.sender]) revert NotGuardian(msg.sender);
        if (pendingRecovery.proposedOwner == address(0)) revert NoActiveRecovery();
        if (pendingRecovery.executableAt != 0) revert RecoveryAlreadyReady(pendingRecovery.executableAt);
        if (hasConfirmed[msg.sender]) revert AlreadyConfirmed(msg.sender);

        hasConfirmed[msg.sender] = true;
        uint256 confirmations = ++pendingRecovery.confirmations;

        emit RecoveryConfirmed(msg.sender, confirmations);

        if (confirmations >= threshold) _markReady();
    }

    /// @notice 当前主人否决这一轮恢复。钥匙还在自己手里时，用它挡住串通的守护者。
    function cancelRecovery() external {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        address proposed = pendingRecovery.proposedOwner;
        if (proposed == address(0)) revert NoActiveRecovery();

        _clearRecovery();
        emit RecoveryCancelled(proposed, msg.sender);
    }

    /// @notice 安全期结束后换主人。谁来调用都行，通常是新主人自己。
    function executeRecovery() external {
        Recovery memory recovery = pendingRecovery;
        if (recovery.proposedOwner == address(0) || recovery.executableAt == 0) revert RecoveryNotReady();
        if (block.timestamp < recovery.executableAt) revert SecurityPeriodActive(recovery.executableAt);

        address previous = owner;
        _clearRecovery();
        owner = recovery.proposedOwner;

        emit RecoveryExecuted(previous, recovery.proposedOwner);
        emit OwnershipTransferred(previous, recovery.proposedOwner);
    }

    function phase() public view returns (Phase) {
        if (pendingRecovery.proposedOwner == address(0)) return Phase.Idle;
        if (pendingRecovery.executableAt == 0) return Phase.Collecting;
        if (block.timestamp < pendingRecovery.executableAt) return Phase.Waiting;
        return Phase.Ready;
    }

    function getGuardians() external view returns (address[] memory) {
        return guardians;
    }

    function _markReady() internal {
        uint256 executableAt = block.timestamp + securityPeriod;
        pendingRecovery.executableAt = executableAt;
        emit RecoveryReady(pendingRecovery.proposedOwner, executableAt);
    }

    function _clearRecovery() internal {
        uint256 n = guardians.length;
        for (uint256 i = 0; i < n; i++) {
            delete hasConfirmed[guardians[i]];
        }
        delete pendingRecovery;
    }

    function _setGuardians(address[] memory next) internal {
        uint256 oldLen = guardians.length;
        for (uint256 i = 0; i < oldLen; i++) {
            isGuardian[guardians[i]] = false;
        }
        delete guardians;

        uint256 n = next.length;
        if (n == 0 || n > MAX_GUARDIANS) revert InvalidGuardians();

        for (uint256 i = 0; i < n; i++) {
            address guardian = next[i];
            if (guardian == address(0) || guardian == owner || isGuardian[guardian]) revert InvalidGuardians();
            isGuardian[guardian] = true;
            guardians.push(guardian);
        }
    }
}
