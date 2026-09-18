// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IPoints {
    event PointsAccrued(address indexed user, uint256 amount);

    function pointsOf(address user) external view returns (uint256);
}
