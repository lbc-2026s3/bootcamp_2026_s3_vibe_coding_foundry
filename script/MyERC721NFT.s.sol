// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyERC721NFT} from "../src/MyERC721NFT.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyERC721NFT，并将地址写入 deployments/MyERC721NFT/
contract MyERC721NFTScript is BaseScript {
    MyERC721NFT public nft;

    function run() public broadcaster {
        nft = new MyERC721NFT();
        saveContract("MyERC721NFT", address(nft));
    }
}
