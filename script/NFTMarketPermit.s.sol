// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyTokenERC1363} from "../src/MyTokenERC1363.sol";
import {MyERC721NFT} from "../src/MyERC721NFT.sol";
import {NFTMarketPermit} from "../src/NFTMarketPermit.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyTokenERC1363 + MyERC721NFT（铸造 1 枚给部署人）+ NFTMarketPermit
/// @dev 部署人为白名单签名 owner
contract NFTMarketPermitScript is BaseScript {
    /// @dev 见 res/ipfslink.txt
    string constant TOKEN_URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";

    MyTokenERC1363 public token;
    MyERC721NFT public nft;
    NFTMarketPermit public market;
    uint256 public mintedTokenId;

    function run() public broadcaster {
        token = new MyTokenERC1363();
        nft = new MyERC721NFT();
        mintedTokenId = nft.mint(deployer, TOKEN_URI);
        market = new NFTMarketPermit(token, nft, deployer);

        saveContract("MyTokenERC1363", address(token));
        saveContract("MyERC721NFT", address(nft));
        saveContract("NFTMarketPermit", address(market));
    }
}
