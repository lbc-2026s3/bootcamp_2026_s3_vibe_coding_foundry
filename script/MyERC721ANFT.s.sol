// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyERC721ANFT} from "../src/MyERC721ANFT.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyERC721ANFT，批量铸造 3 枚给部署人，并将地址写入 deployments/MyERC721ANFT/
contract MyERC721ANFTScript is BaseScript {
    /// @dev 见 res/ipfslink.txt；该 CID 是单个 metadata JSON，所有 token 共用
    string constant COLLECTION_URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";
    uint256 constant MINT_QUANTITY = 3;

    MyERC721ANFT public nft;

    function run() public broadcaster {
        nft = new MyERC721ANFT(COLLECTION_URI);
        nft.mint(deployer, MINT_QUANTITY);
        saveContract("MyERC721ANFT", address(nft));
    }
}
