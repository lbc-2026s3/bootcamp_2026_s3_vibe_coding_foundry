// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Governor} from "openzeppelin-contracts/contracts/governance/Governor.sol";
import {GovernorSettings} from "openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "openzeppelin-contracts/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";

/// @title DAOGov — 基于 OpenZeppelin Governor 的 DAO 治理
/// @notice 使用 `DAOToken` 投票；通过后经 `TimelockController` 延迟再执行。
/// @dev `DAOBank` 的 owner 应为 Timelock（不是本合约）。流程：Succeeded → queue → 等 minDelay → execute。
contract DAOGov is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /// @param token_ 治理代币（`DAOToken` / 任意 `IVotes`）
    /// @param timelock_ 执行延迟控制器；Bank 等受管合约的 owner 应指向它
    /// @param votingDelay_ 提案创建后到开始投票的区块数
    /// @param votingPeriod_ 投票持续区块数
    /// @param proposalThreshold_ 发起提案所需最低票权（已委托）
    /// @param quorumNumerator_ 法定人数占总供给的百分比分子（分母默认 100）
    constructor(
        IVotes token_,
        TimelockController timelock_,
        uint48 votingDelay_,
        uint32 votingPeriod_,
        uint256 proposalThreshold_,
        uint256 quorumNumerator_
    )
        Governor("DAOGov")
        GovernorSettings(votingDelay_, votingPeriod_, proposalThreshold_)
        GovernorVotes(token_)
        GovernorVotesQuorumFraction(quorumNumerator_)
        GovernorTimelockControl(timelock_)
    {}

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
