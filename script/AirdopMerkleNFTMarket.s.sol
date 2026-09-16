// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MyTokenERC2612Permit} from "../src/MyTokenERC2612Permit.sol";
import {MyERC721NFT} from "../src/MyERC721NFT.sol";
import {AirdopMerkleNFTMarket} from "../src/AirdopMerkleNFTMarket.sol";
import {MerkleWhitelist} from "../src/libraries/MerkleWhitelist.sol";
import {BaseScript} from "./BaseScript.s.sol";

/// @notice 部署 MyTokenERC2612Permit + MyERC721NFT（铸造 1 枚给部署人）+ AirdopMerkleNFTMarket
/// @dev 白名单长度任意；部署前按实际名单改 _whitelist()
contract AirdopMerkleNFTMarketScript is BaseScript {
    /// @dev 见 res/ipfslink.txt
    string constant TOKEN_URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";

    MyTokenERC2612Permit public token;
    MyERC721NFT public nft;
    AirdopMerkleNFTMarket public market;
    uint256 public mintedTokenId;
    bytes32 public merkleRoot;

    function run() public broadcaster {
        address[] memory whitelist = _whitelist();
        merkleRoot = MerkleWhitelist.root(whitelist);

        token = new MyTokenERC2612Permit();
        nft = new MyERC721NFT();
        mintedTokenId = nft.mint(deployer, TOKEN_URI);
        market = new AirdopMerkleNFTMarket(token, nft, deployer, merkleRoot);

        saveContract("MyTokenERC2612Permit", address(token));
        saveContract("MyERC721NFT", address(nft));
        saveContract("AirdopMerkleNFTMarket", address(market));
    }

    /// @dev 示例 8 个占位地址（确定性 makeAddr）；上线前替换，长度可改为 12 / 24 / 任意
    function _whitelist() internal returns (address[] memory a) {
        a = new address[](8);
        for (uint256 i = 0; i < a.length; ++i) {
            a[i] = makeAddr(string.concat("airdrop-wl-", vm.toString(i)));
        }
    }
}
