// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/// @notice PointsVault 共享业务存储（所有 facet 经 diamond 的 delegatecall 读写同一份）。
/// @dev 独立 slot；V2 只能在 struct 末尾追加字段，禁止重排 / 删除。
library LibAppStorage {
    bytes32 internal constant APP_STORAGE_POSITION = keccak256("points.vault.app.storage");

    struct AppStorage {
        mapping(address => uint256) balances;
        mapping(address => uint256) points;
        uint256 totalDeposits;
        // --- V2 追加 ---
        uint256 withdrawFeeBps;
        uint256 protocolFees;
        bool v2Initialized;
    }

    function appStorage() internal pure returns (AppStorage storage s) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
