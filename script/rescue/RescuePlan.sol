// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Vm, VmSafe} from "forge-std/Vm.sol";

/// @notice 准备脚本写入、营救脚本读取。按 chainId 分文件，anvil 和 Sepolia 互不覆盖。
library RescuePlan {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Data {
        address victim;
        address sponsor;
        address token;
        address nft;
        address delegate;
        uint256 amount;
        uint256[] tokenIds;
    }

    function path(uint256 chainId) internal pure returns (string memory) {
        return string.concat("deployments/RescuePlan/RescuePlan_", vm.toString(chainId), ".json");
    }

    /// @dev 模拟阶段不落盘，避免把模拟地址写成正式结果。
    function store(Data memory data) internal {
        if (
            !vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)
                && !vm.isContext(VmSafe.ForgeContext.ScriptResume)
        ) {
            return;
        }

        string memory obj = "rescuePlan";
        vm.serializeAddress(obj, "victim", data.victim);
        vm.serializeAddress(obj, "sponsor", data.sponsor);
        vm.serializeAddress(obj, "token", data.token);
        vm.serializeAddress(obj, "nft", data.nft);
        vm.serializeAddress(obj, "delegate", data.delegate);
        vm.serializeUint(obj, "amount", data.amount);
        string memory json = vm.serializeUint(obj, "tokenIds", data.tokenIds);

        vm.createDir("deployments/RescuePlan", true);
        vm.writeJson(json, path(block.chainid));
    }

    function load() internal view returns (Data memory data) {
        string memory json = vm.readFile(path(block.chainid));
        data.victim = vm.parseJsonAddress(json, ".victim");
        data.sponsor = vm.parseJsonAddress(json, ".sponsor");
        data.token = vm.parseJsonAddress(json, ".token");
        data.nft = vm.parseJsonAddress(json, ".nft");
        data.delegate = vm.parseJsonAddress(json, ".delegate");
        data.amount = vm.parseJsonUint(json, ".amount");
        data.tokenIds = vm.parseJsonUintArray(json, ".tokenIds");
    }
}
