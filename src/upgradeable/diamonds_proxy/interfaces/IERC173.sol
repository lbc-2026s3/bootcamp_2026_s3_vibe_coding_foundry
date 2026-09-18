// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/// @notice ERC-173 所有权（钻石把 owner 存在 LibDiamond 槽，而不是 OZ Ownable 布局）。
interface IERC173 {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() external view returns (address owner_);

    function transferOwnership(address _newOwner) external;
}
