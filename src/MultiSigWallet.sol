// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @notice 简单多签钱包：默认 2/3。流程为 propose → confirm → execute
contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;

    /// @notice 执行提案所需的最少确认数（默认 2）
    uint256 public immutable threshold;

    struct Proposal {
        address to;
        uint256 value;
        bytes data;
        uint256 confirmations;
        bool executed;
    }

    /// @notice proposalId 从 0 起递增
    uint256 public proposalCount;
    /// @notice 提案详情：proposalId => Proposal
    mapping(uint256 => Proposal) public proposals;
    /// @notice 确认记录：proposalId => owner => 是否已确认
    mapping(uint256 => mapping(address => bool)) public confirmed;

    event Deposit(address indexed sender, uint256 amount);
    event Proposed(uint256 indexed proposalId, address indexed proposer, address to, uint256 value, bytes data);
    event Confirmed(uint256 indexed proposalId, address indexed owner);
    event Executed(uint256 indexed proposalId, address indexed executor, bool success);

    error NotOwner();
    error InvalidOwners();
    error InvalidThreshold();
    error ProposalNotFound();
    error AlreadyConfirmed();
    error AlreadyExecuted();
    error NotEnoughConfirmations();
    error ExecutionFailed();

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    /// @param _owners 多签持有人列表（默认场景传 3 个地址）
    /// @param _threshold 确认门槛（默认场景传 2）
    constructor(address[] memory _owners, uint256 _threshold) {
        uint256 n = _owners.length;
        if (n == 0) revert InvalidOwners();
        if (_threshold == 0 || _threshold > n) revert InvalidThreshold();

        for (uint256 i = 0; i < n; i++) {
            address owner = _owners[i];
            if (owner == address(0) || isOwner[owner]) revert InvalidOwners();
            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    /// @notice 接收 ETH；取出需经 propose → confirm → execute，非转入人可自行取回
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice 多签持有人提交提案；提交者自动计入一次确认
    function propose(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256 proposalId) {
        proposalId = proposalCount++;
        Proposal storage p = proposals[proposalId];
        p.to = to;
        p.value = value;
        p.data = data;
        p.confirmations = 1;
        confirmed[proposalId][msg.sender] = true;

        emit Proposed(proposalId, msg.sender, to, value, data);
        emit Confirmed(proposalId, msg.sender);
    }

    /// @notice 其他多签持有人对提案进行确认
    function confirm(uint256 proposalId) external onlyOwner {
        if (proposalId >= proposalCount) revert ProposalNotFound();
        Proposal storage p = proposals[proposalId];
        if (p.executed) revert AlreadyExecuted();
        if (confirmed[proposalId][msg.sender]) revert AlreadyConfirmed();

        confirmed[proposalId][msg.sender] = true;
        p.confirmations += 1;

        emit Confirmed(proposalId, msg.sender);
    }

    /// @notice 达到门槛后，任何人都可以执行提案
    function execute(uint256 proposalId) external {
        if (proposalId >= proposalCount) revert ProposalNotFound();
        Proposal storage p = proposals[proposalId];
        if (p.executed) revert AlreadyExecuted();
        if (p.confirmations < threshold) revert NotEnoughConfirmations();

        // Checks-Effects-Interactions：先标记已执行，再外部调用
        p.executed = true;

        (bool success,) = p.to.call{value: p.value}(p.data);
        if (!success) revert ExecutionFailed();

        emit Executed(proposalId, msg.sender, true);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getProposal(uint256 proposalId)
        external
        view
        returns (address to, uint256 value, bytes memory data, uint256 confirmations, bool executed)
    {
        if (proposalId >= proposalCount) revert ProposalNotFound();
        Proposal storage p = proposals[proposalId];
        return (p.to, p.value, p.data, p.confirmations, p.executed);
    }

    function isConfirmed(uint256 proposalId, address owner) external view returns (bool) {
        return confirmed[proposalId][owner];
    }
}
