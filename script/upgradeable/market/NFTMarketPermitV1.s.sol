// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MyTokenERC2612Permit} from "../../../src/MyTokenERC2612Permit.sol";
import {MyERC721UpgradeableNFT} from "../../../src/upgradeable/MyERC721UpgradeableNFT.sol";
import {NFTMarketPermitV1} from "../../../src/upgradeable/market/NFTMarketPermitV1.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice 一并部署 MyTokenERC2612Permit + UUPS MyERC721UpgradeableNFT + UUPS NFTMarketPermitV1
/// @dev OZ v5 ReentrancyGuard 已用 ERC-7201（运行时安全），但 upgrades-core 仍报 constructor；需 unsafeAllow
contract NFTMarketPermitV1Script is BaseScript {
    /// @dev 见 res/ipfslink.txt
    string constant TOKEN_URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";

    MyTokenERC2612Permit public token;
    MyERC721UpgradeableNFT public nft;
    NFTMarketPermitV1 public market;
    uint256 public mintedTokenId;

    function run() public broadcaster {
        token = new MyTokenERC2612Permit();

        address nftProxy = Upgrades.deployUUPSProxy(
            "MyERC721UpgradeableNFT.sol:MyERC721UpgradeableNFT",
            abi.encodeCall(MyERC721UpgradeableNFT.initialize, (deployer))
        );
        nft = MyERC721UpgradeableNFT(nftProxy);
        mintedTokenId = nft.mint(deployer, TOKEN_URI);

        Options memory opts;
        // OZ ReentrancyGuard（@custom:stateless）有 constructor；validator 尚未豁免，见 OZ issue #116
        opts.unsafeAllow = "constructor";

        address marketProxy = Upgrades.deployUUPSProxy(
            "NFTMarketPermitV1.sol:NFTMarketPermitV1",
            abi.encodeCall(
                NFTMarketPermitV1.initialize, (IERC20(address(token)), IERC721(address(nft)), deployer)
            ),
            opts
        );
        market = NFTMarketPermitV1(marketProxy);

        saveContract("MyTokenERC2612Permit", address(token));
        saveContract("MyERC721UpgradeableNFT", nftProxy);
        saveContract("MyERC721UpgradeableNFT_Implementation", Upgrades.getImplementationAddress(nftProxy));
        saveContract("NFTMarketPermitV1", marketProxy);
        saveContract("NFTMarketPermitV1_Implementation", Upgrades.getImplementationAddress(marketProxy));
    }
}
