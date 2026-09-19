// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {AutomationCompatibleInterface} from "../interfaces/AutomationCompatibleInterface.sol";

/// @title ArmedCounter — 条件触发 demo（CLA Custom Logic / CRE Cron + offchain check）
/// @notice 只有 `arm()` 之后，`checkUpkeep` 才返回 true；`performUpkeep` 执行一次后自动解除武装（幂等）。
contract ArmedCounter is AutomationCompatibleInterface {
    bool public armed;
    uint256 public counter;

    event Armed(address indexed by);
    event Performed(uint256 indexed newCounter);

    error NotArmed();

    function arm() external {
        armed = true;
        emit Armed(msg.sender);
    }

    /// @dev CRE / Automation 链下模拟；不要依赖它被 onchain 调用。
    function checkUpkeep(bytes calldata /* checkData */)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = armed;
        performData = "";
    }

    /// @dev 执行前再校验 `armed`，防止重复/抢跑导致白干 gas。
    function performUpkeep(bytes calldata /* performData */) external override {
        if (!armed) revert NotArmed();
        armed = false;
        unchecked {
            ++counter;
        }
        emit Performed(counter);
    }
}
