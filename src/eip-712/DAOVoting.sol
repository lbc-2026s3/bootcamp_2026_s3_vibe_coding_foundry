// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

/// @title DAOVoting — 离线签名、链上批量计票
/// @notice 投票人用 EIP-712 签 `Vote`，任何人可以代付 gas 提交。中继改不了已签名字段。
/// @dev 票数 `weight` 以签名内容为准，本合约不读取代币余额。同一地址对同一提案只能投一次；
///      `nonce` 按投票人递增，用过的签名不能再提交。`deadline` 是 unix 秒，该时刻仍有效，再晚一笔就过期。
contract DAOVoting is EIP712 {
    using ECDSA for bytes32;

    string public constant NAME = "DAOVoting";
    string public constant VERSION = "1";

    /// @dev Vote(uint256 proposalId,bool support,address voter,uint256 weight,uint256 nonce,uint256 deadline)
    bytes32 public constant VOTE_TYPEHASH = keccak256(
        "Vote(uint256 proposalId,bool support,address voter,uint256 weight,uint256 nonce,uint256 deadline)"
    );

    struct Vote {
        uint256 proposalId;
        bool support;
        address voter;
        uint256 weight;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(uint256 proposalId => mapping(address voter => bool voted)) public hasVoted;
    mapping(uint256 proposalId => uint256 votes) public forVotes;
    mapping(uint256 proposalId => uint256 votes) public againstVotes;
    /// @notice 该地址下一张有效选票必须使用的 nonce
    mapping(address voter => uint256 nonce) public nonces;

    error EmptyBatch();
    error LengthMismatch(uint256 votesLength, uint256 signaturesLength);
    error InvalidSigner(address recovered, address voter);
    error InvalidNonce(address voter, uint256 expected, uint256 actual);
    error AlreadyVoted(uint256 proposalId, address voter);
    error ZeroWeight(address voter);
    error SignatureExpired(uint256 deadline, uint256 currentTime);

    event VoteCast(
        uint256 indexed proposalId, address indexed voter, bool support, uint256 weight, uint256 nonce, uint256 deadline
    );

    constructor() EIP712(NAME, VERSION) {}

    /// @notice 批量提交离线选票。任一笔失败则整笔交易回滚。
    /// @param votes 选票，字段必须与签名时一致
    /// @param signatures 与 `votes` 一一对应的 65 字节签名（r ‖ s ‖ v）
    function castVotesBySig(Vote[] calldata votes, bytes[] calldata signatures) external {
        uint256 length = votes.length;
        if (length == 0) revert EmptyBatch();
        if (length != signatures.length) revert LengthMismatch(length, signatures.length);

        for (uint256 i = 0; i < length; ++i) {
            _castVoteBySig(votes[i], signatures[i]);
        }
    }

    function _castVoteBySig(Vote calldata vote, bytes calldata signature) private {
        if (block.timestamp > vote.deadline) revert SignatureExpired(vote.deadline, block.timestamp);

        bytes32 digest = _hashVote(vote);
        address signer = digest.recover(signature);
        if (signer != vote.voter) revert InvalidSigner(signer, vote.voter);

        uint256 expectedNonce = nonces[signer];
        if (vote.nonce != expectedNonce) revert InvalidNonce(signer, expectedNonce, vote.nonce);
        if (hasVoted[vote.proposalId][signer]) revert AlreadyVoted(vote.proposalId, signer);
        if (vote.weight == 0) revert ZeroWeight(signer);

        nonces[signer] = expectedNonce + 1;
        hasVoted[vote.proposalId][signer] = true;

        if (vote.support) {
            forVotes[vote.proposalId] += vote.weight;
        } else {
            againstVotes[vote.proposalId] += vote.weight;
        }

        emit VoteCast(vote.proposalId, signer, vote.support, vote.weight, expectedNonce, vote.deadline);
    }

    function _hashVote(Vote calldata vote) private view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    VOTE_TYPEHASH,
                    vote.proposalId,
                    vote.support,
                    vote.voter,
                    vote.weight,
                    vote.nonce,
                    vote.deadline
                )
            )
        );
    }
}
