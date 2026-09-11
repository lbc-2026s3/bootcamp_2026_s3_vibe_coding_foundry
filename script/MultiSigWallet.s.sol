// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署默认 2/3 多签钱包
/// @dev 通过环境变量传入三个 owner：OWNER1 / OWNER2 / OWNER3
contract MultiSigWalletScript is BaseScript {
    MultiSigWallet public wallet;

    function run() public broadcaster {
        address owner1 = vm.envAddress("OWNER1");
        address owner2 = vm.envAddress("OWNER2");
        address owner3 = vm.envAddress("OWNER3");

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSigWallet(owners, 2);
        saveContract("MultiSigWallet", address(wallet));

        console.log("MultiSigWallet deployed at", address(wallet));
        console.log("threshold = 2 / owners = 3");
    }
}
