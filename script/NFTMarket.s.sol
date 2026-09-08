// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyTokenERC1363} from "../src/MyTokenERC1363.sol";
import {MyERC721NFT} from "../src/MyERC721NFT.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyTokenERC1363 + MyERC721NFT（铸造 1 枚给部署人）+ NFTMarket
contract NFTMarketScript is BaseScript {
    /// @dev 见 res/ipfslink.txt
    string constant TOKEN_URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";

    MyTokenERC1363 public token;
    MyERC721NFT public nft;
    NFTMarket public market;
    uint256 public mintedTokenId;

    function run() public broadcaster {
        token = new MyTokenERC1363();
        nft = new MyERC721NFT();
        mintedTokenId = nft.mint(deployer, TOKEN_URI);
        market = new NFTMarket(token, nft);

        saveContract("MyTokenERC1363", address(token));
        saveContract("MyERC721NFT", address(nft));
        saveContract("NFTMarket", address(market));
    }
}
