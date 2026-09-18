// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IPoints} from "../interfaces/IPoints.sol";
import {LibAppStorage} from "./LibAppStorage.sol";

/// @notice 存取款核心逻辑，VaultFacet / PointsFacet / VaultFacetV2 共用。
/// @dev OZ ReentrancyGuard 使用 ERC-7201 槽，经 diamond delegatecall 时各 facet 共享同一把锁。
abstract contract VaultBase is ReentrancyGuard {
    using LibAppStorage for LibAppStorage.AppStorage;

    uint256 internal constant BPS_DENOMINATOR = 10_000;

    function _deposit(address user, uint256 amount) internal {
        if (amount == 0) revert IVault.ZeroAmount();
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.balances[user] += amount;
        s.totalDeposits += amount;
        emit IVault.Deposited(user, amount);
    }

    function _accruePoints(address user, uint256 amount) internal {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.points[user] += amount;
        emit IPoints.PointsAccrued(user, amount);
    }

    function _withdraw(address user, uint256 amount, uint256 feeBps) internal {
        if (amount == 0) revert IVault.ZeroAmount();
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        uint256 balance = s.balances[user];
        if (amount > balance) revert IVault.InsufficientBalance();

        uint256 fee = (amount * feeBps) / BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        s.balances[user] = balance - amount;
        s.totalDeposits -= amount;
        if (fee != 0) s.protocolFees += fee;

        emit IVault.Withdrawn(user, payout, fee);

        (bool ok,) = user.call{value: payout}("");
        if (!ok) revert IVault.TransferFailed();
    }
}
