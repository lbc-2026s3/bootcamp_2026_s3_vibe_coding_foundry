// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {UniswapV2Pair} from "uniswapv2/UniswapV2Pair.sol";

/// @dev forge script script/uniswapv2/ComputePairInitCodeHash.s.sol
///      Library 已改为 type(UniswapV2Pair).creationCode，此脚本仅供对照
contract ComputePairInitCodeHash is Script {
    function run() public pure {
        bytes32 hash = keccak256(type(UniswapV2Pair).creationCode);
        console2.logBytes32(hash);
    }
}
