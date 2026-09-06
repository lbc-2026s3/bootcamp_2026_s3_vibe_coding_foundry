// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

abstract contract BaseScript is Script {

    function setUp() public virtual {}

    function saveContract(string memory name, address addr) internal {
        string memory chainId = vm.toString(block.chainid);

        string memory dirPath = string.concat("deployments/", name);

        // Foundry cheatcode: 创建目录，等价 mkdir -p，已存在不会报错
        vm.createDir(dirPath, true);

        string memory json1 = "key";
        string memory finalJson = vm.serializeAddress(json1, "address", addr);

        string memory fullFilePath = string.concat(dirPath, "/", name, "_", chainId, ".json");

        try vm.writeJson(finalJson, fullFilePath) {
            // success
        } catch {
            revert(string.concat(
                "saveContract failed! Please manually run: mkdir -p ",
                dirPath
            ));
        }
    }

    modifier broadcaster() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}