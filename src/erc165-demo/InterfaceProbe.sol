// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC165Checker} from "openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

/// @notice 查询方:对比「裸 staticcall」与 OZ ERC165Checker 的探测结果
contract InterfaceProbe {
    using ERC165Checker for address;

    /// @dev 不安全示范:直接调 supportsInterface;对方无该函数会 revert,EOA 也会失败
    function rawSupportsInterface(address account, bytes4 interfaceId) external view returns (bool) {
        return IERC165(account).supportsInterface(interfaceId);
    }

    /// @dev 安全探测:先确认对方真实现了 ERC-165,再查具体接口
    function safeSupportsInterface(address account, bytes4 interfaceId) external view returns (bool) {
        return account.supportsInterface(interfaceId);
    }

    function supportsERC165(address account) external view returns (bool) {
        return account.supportsERC165();
    }
}
