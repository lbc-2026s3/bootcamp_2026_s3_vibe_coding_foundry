// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

/// @title GovernanceToken — 带提案投票的治理代币
/// @notice 票权来自 OpenZeppelin `ERC20Votes`：余额默认不算票，必须 `delegate` 之后才进入 checkpoint。
/// @dev 快照区块是提案创建时的 `block.number + VOTING_DELAY`。投票从下一区块开始，
///      权重用 `getPastVotes`，所以快照结束之后的转账、以及同一笔交易里的闪电贷，都改不了这张票。
///      `executeProposal` 只把通过的提案标成已执行，不会替提案去调用别的合约。
contract GovernanceToken is ERC20, ERC20Votes {
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    /// @notice 发起提案所需的历史票权。看的是上一块的 `getPastVotes`，本块刚委托的票不算。
    uint256 public constant PROPOSAL_THRESHOLD = 1_000e18;
    /// @notice 提案创建后再过这么多块，才冻结快照。投票要等到快照区块结束之后。
    uint256 public constant VOTING_DELAY = 1;
    /// @notice 可投票的区块数。快照区块本身不能投。
    uint256 public constant VOTING_PERIOD = 21600; // 3 days
    /// @notice 赞成票至少要达到快照总供给的 4%，并且严格多于反对票。
    uint256 public constant QUORUM_NUMERATOR = 4;
    uint256 public constant QUORUM_DENOMINATOR = 100;
    uint256 public constant MAX_DESCRIPTION_BYTES = 1024;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 snapshotBlock;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
    }

    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed,
        Canceled
    }

    mapping(uint256 proposalId => Proposal) public proposals;
    mapping(uint256 proposalId => mapping(address voter => bool)) public hasVoted;
    uint256 public proposalCount;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 snapshotBlock,
        uint256 startBlock,
        uint256 endBlock
    );
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    error EmptyDescription();
    error DescriptionTooLong(uint256 length, uint256 max);
    error InsufficientVotingPower(address account, uint256 votes, uint256 required);
    error ProposalNotFound(uint256 proposalId);
    error VotingNotStarted(uint256 proposalId, uint256 startBlock);
    error VotingEnded(uint256 proposalId, uint256 endBlock);
    error VotingNotEnded(uint256 proposalId, uint256 endBlock);
    error AlreadyVoted(uint256 proposalId, address voter);
    error NoVotingPower(address account);
    error ProposalAlreadyExecuted(uint256 proposalId);
    error ProposalAlreadyCanceled(uint256 proposalId);
    error ProposalNotPassed(uint256 proposalId, uint256 forVotes, uint256 againstVotes);
    error QuorumNotReached(uint256 proposalId, uint256 forVotes, uint256 quorum);
    error NotProposer(address account, address proposer);
    error CancelWindowClosed(uint256 proposalId);

    constructor() ERC20("Governance Token", "GOV") EIP712("Governance Token", "1") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// @notice 创建提案。调用者在上一块的票权必须不少于 `PROPOSAL_THRESHOLD`。
    /// @dev 快照是 `block.number + VOTING_DELAY`。投票从下一块开始，所以快照区块里的转账会计入票数，
    ///      快照之后的转账不会。
    function propose(string calldata description) external returns (uint256 proposalId) {
        uint256 length = bytes(description).length;
        if (length == 0) revert EmptyDescription();
        if (length > MAX_DESCRIPTION_BYTES) revert DescriptionTooLong(length, MAX_DESCRIPTION_BYTES);
        if (block.number == 0) revert InsufficientVotingPower(msg.sender, 0, PROPOSAL_THRESHOLD);

        uint256 proposerVotes = getPastVotes(msg.sender, block.number - 1);
        if (proposerVotes < PROPOSAL_THRESHOLD) {
            revert InsufficientVotingPower(msg.sender, proposerVotes, PROPOSAL_THRESHOLD);
        }

        proposalId = ++proposalCount;
        uint256 snapshotBlock = block.number + VOTING_DELAY;
        uint256 startBlock = snapshotBlock + 1;
        uint256 endBlock = snapshotBlock + VOTING_PERIOD;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            description: description,
            snapshotBlock: snapshotBlock,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            executed: false,
            canceled: false
        });

        emit ProposalCreated(proposalId, msg.sender, description, snapshotBlock, startBlock, endBlock);
    }

    /// @notice 对进行中的提案投票。权重是快照区块结束时的票权，不是当前余额。
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = _requireProposal(proposalId);
        if (proposal.canceled) revert ProposalAlreadyCanceled(proposalId);
        if (block.number < proposal.startBlock) revert VotingNotStarted(proposalId, proposal.startBlock);
        if (block.number > proposal.endBlock) revert VotingEnded(proposalId, proposal.endBlock);
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted(proposalId, msg.sender);

        uint256 votes = getPastVotes(msg.sender, proposal.snapshotBlock);
        if (votes == 0) revert NoVotingPower(msg.sender);

        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    /// @notice 投票结束后，赞成票严格多于反对票且达到法定人数时，把提案标为已执行。
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = _requireProposal(proposalId);
        if (proposal.canceled) revert ProposalAlreadyCanceled(proposalId);
        if (proposal.executed) revert ProposalAlreadyExecuted(proposalId);
        if (block.number <= proposal.endBlock) revert VotingNotEnded(proposalId, proposal.endBlock);
        if (proposal.forVotes <= proposal.againstVotes) {
            revert ProposalNotPassed(proposalId, proposal.forVotes, proposal.againstVotes);
        }

        uint256 required = quorum(proposal.snapshotBlock);
        if (proposal.forVotes < required) {
            revert QuorumNotReached(proposalId, proposal.forVotes, required);
        }

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    /// @notice 提案人可以在投票结束前撤回提案。
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = _requireProposal(proposalId);
        if (proposal.canceled) revert ProposalAlreadyCanceled(proposalId);
        if (proposal.executed) revert ProposalAlreadyExecuted(proposalId);
        if (msg.sender != proposal.proposer) revert NotProposer(msg.sender, proposal.proposer);
        if (block.number > proposal.endBlock) revert CancelWindowClosed(proposalId);

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /// @notice 快照总供给的 4%。未委托的代币也算在总供给里。
    function quorum(uint256 timepoint) public view returns (uint256) {
        return (getPastTotalSupply(timepoint) * QUORUM_NUMERATOR) / QUORUM_DENOMINATOR;
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = _requireProposal(proposalId);
        if (proposal.canceled) return ProposalState.Canceled;
        if (proposal.executed) return ProposalState.Executed;
        if (block.number < proposal.startBlock) return ProposalState.Pending;
        if (block.number <= proposal.endBlock) return ProposalState.Active;
        if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorum(proposal.snapshotBlock)) {
            return ProposalState.Defeated;
        }
        return ProposalState.Succeeded;
    }

    function _requireProposal(uint256 proposalId) internal view returns (Proposal storage proposal) {
        proposal = proposals[proposalId];
        if (proposalId == 0 || proposal.id != proposalId) revert ProposalNotFound(proposalId);
    }

    /// @dev `ERC20` 和 `ERC20Votes` 都实现了 `_update`，必须显式消歧。
    ///      `super._update` 会先走 `ERC20Votes`，转账时同步票权 checkpoint。
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }
}
