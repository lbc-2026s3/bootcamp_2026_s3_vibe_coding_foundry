// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// ---------------------------------------------------------------------------
// MyNFT — 付费 ERC721
//
// 环境变量（可选）：
//   NAME   — 默认 "MyNFT"
//   SYMBOL — 默认 "MNFT"
//
// forge script script/nft/DeployMyNFT.s.sol:DeployMyNFT \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {MyNFT} from "../../src/nft/MyNFT.sol";

contract DeployMyNFT is BaseScript {
    MyNFT public nft;

    function run() public broadcaster {
        string memory name_ = vm.envOr("NAME", string("MyNFT"));
        string memory symbol_ = vm.envOr("SYMBOL", string("MNFT"));

        nft = new MyNFT(name_, symbol_);
        saveContract("MyNFT", address(nft));

        console.log("MyNFT:  ", address(nft));
        console.log("name:   ", name_);
        console.log("symbol: ", symbol_);
        console.log("owner:  ", nft.owner());
    }
}
