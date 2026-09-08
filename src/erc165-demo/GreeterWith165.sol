// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import {IGreeter} from "./IGreeter.sol";

/// @notice 正例:继承 OZ ERC165,对外声明支持 IERC165 + IGreeter
contract GreeterWith165 is ERC165, IGreeter {
    string private _greeting;

    constructor(string memory greeting_) {
        _greeting = greeting_;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IGreeter).interfaceId || super.supportsInterface(interfaceId);
    }

    function greet() external view override returns (string memory) {
        return _greeting;
    }

    function setGreeting(string calldata newGreeting) external override {
        _greeting = newGreeting;
    }
}
