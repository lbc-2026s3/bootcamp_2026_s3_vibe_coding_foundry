// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MyERC721UpgradeableNFT} from "../../src/upgradeable/MyERC721UpgradeableNFT.sol";
import {BaseScript} from "../BaseScript.s.sol";

/// @notice 用 OpenZeppelin Foundry Upgrades 部署 UUPS 代理版 MyERC721UpgradeableNFT，铸造 1 枚给部署人
contract MyERC721UpgradeableNFTScript is BaseScript {
    /// @dev 见 res/ipfslink.txt
    string constant TOKEN_URI = "ipfs://QmTg75dRHikf7joDYxiMMznQh9MSpF27MVfzeZi6eT94TR";

    MyERC721UpgradeableNFT public nft;
    uint256 public mintedTokenId;

    function run() public broadcaster {
        // Upgrades.deployUUPSProxy 内部顺序：
        // 1) ffi 调 `@openzeppelin/upgrades-core validate`，按 artifact 的 AST/storageLayout 做升级安全检查
        // 2) 部署 implementation（constructor 里 `_disableInitializers()`，禁止直接 initialize）
        // 3) 部署 ERC1967Proxy(impl, initializerData)；proxy 构造时 delegatecall 到 initialize
        //    → name/symbol/owner 写在 proxy 存储里，用户之后只跟 proxy 交互
        address proxy = Upgrades.deployUUPSProxy(
            "MyERC721UpgradeableNFT.sol:MyERC721UpgradeableNFT", // 按 artifact 名找实现合约，不是地址
            abi.encodeCall(MyERC721UpgradeableNFT.initialize, (deployer))
        );
        nft = MyERC721UpgradeableNFT(proxy);
        mintedTokenId = nft.mint(deployer, TOKEN_URI);

        saveContract("MyERC721UpgradeableNFT", proxy);
        saveContract("MyERC721UpgradeableNFT_Implementation", Upgrades.getImplementationAddress(proxy));
    }
}
