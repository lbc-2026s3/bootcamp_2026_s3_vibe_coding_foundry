// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";

error AlreadyInitialized();
error InvalidFeeBps();

/// @notice 不挂到钻石上的一次性 init：经 diamondCut 的 `_init` delegatecall 写入 V2 费率。
/// @dev 上限 10%（1000 bps），避免教学 demo 被设成 100% 抽干。
contract VaultV2Init {
    uint256 internal constant MAX_FEE_BPS = 1_000;

    function init(uint256 feeBps) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        if (s.v2Initialized) revert AlreadyInitialized();
        if (feeBps > MAX_FEE_BPS) revert InvalidFeeBps();
        s.withdrawFeeBps = feeBps;
        s.v2Initialized = true;
    }
}
