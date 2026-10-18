// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// DynamicColorNFT — 纯色动态 ERC721
// 颜色由铸造时间戳对 7 取余决定：红橙黄绿青蓝紫。
// 部署后给广播账户铸造 1 枚，方便在区块浏览器里直接看 tokenURI。
//
// Sepolia 的代码存款 gas 高于本地模拟，gas 上限要加大，否则创建交易会把 gas 烧光后回滚。
// forge script script/nft/DeployDynamicColorNFT.s.sol:DeployDynamicColorNFT \
//   --broadcast --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY \
//   --gas-estimate-multiplier 800 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {DynamicColorNFT} from "../../src/nft/DynamicColorNFT.sol";

contract DeployDynamicColorNFT is BaseScript {
    DynamicColorNFT public nft;

    function run() public broadcaster {
        nft = new DynamicColorNFT();
        saveContract("DynamicColorNFT", address(nft));

        uint256 tokenId = nft.mint(deployer);

        console.log("DynamicColorNFT:", address(nft));
        console.log("minter:", deployer);
        console.log("tokenId:", tokenId);
        console.log("mintedAt:", nft.mintedAt(tokenId));
        console.log("colorIndex:", nft.colorIndexOf(tokenId));
        console.log("color:", nft.colorNameOf(tokenId));
        console.log("hex:", nft.colorHexOf(tokenId));
    }
}
