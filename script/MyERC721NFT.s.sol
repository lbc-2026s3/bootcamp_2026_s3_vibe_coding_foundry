// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyERC721NFT} from "../src/MyERC721NFT.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyERC721NFT，铸造 1 枚给部署人，并将地址写入 deployments/MyERC721NFT/
contract MyERC721NFTScript is BaseScript {
    /// @dev 见 res/ipfslink.txt
    string constant TOKEN_URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";

    MyERC721NFT public nft;
    uint256 public mintedTokenId;

    function run() public broadcaster {
        nft = new MyERC721NFT();
        mintedTokenId = nft.mint(deployer, TOKEN_URI);
        saveContract("MyERC721NFT", address(nft));
    }
}
