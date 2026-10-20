// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// ---------------------------------------------------------------------------
// UniversalNFTCollection — 按当前 RPC 的 chainId 选择配置，部署透明代理。
//
// 一次 forge script 只能连一条链。多链循环见同目录 deploy-multichain.sh。
// OpenZeppelin v5 的 TransparentUpgradeableProxy 会在内部 new ProxyAdmin，
// 构造参数是 (implementation, initialOwner, data)，不要再单独传入 ProxyAdmin。
//
// 本地：
//   forge script script/multichain_nft/DeployUniversalNFT.s.sol:DeployUniversalNFT \
//     --rpc-url local --broadcast \
//     --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//     && cat deployments/LATEST.txt
//
// 可选环境变量：NAME、SYMBOL、FEE_RECIPIENT
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {UniversalNFTCollection} from "../../src/multichain_nft/UniversalNFTCollection.sol";

contract DeployUniversalNFT is BaseScript {
    UniversalNFTCollection public nft;

    function run() public broadcaster {
        (uint256 baseFee, uint256 maxBatchSize, bool supportsBatch, string memory label) = _profile(block.chainid);
        address feeRecipient = vm.envOr("FEE_RECIPIENT", deployer);
        string memory name_ = vm.envOr("NAME", string.concat("Universal NFT ", label));
        string memory symbol_ = vm.envOr("SYMBOL", string.concat("UNI-", label));

        UniversalNFTCollection.ChainConfig memory config = UniversalNFTCollection.ChainConfig({
            chainId: block.chainid,
            baseFee: baseFee,
            maxBatchSize: maxBatchSize,
            supportsBatch: supportsBatch,
            feeRecipient: feeRecipient
        });

        // initialOwner 是 ProxyAdmin 的 owner，不是代理的 admin。业务调用不会被透明代理拦下。
        address proxy = Upgrades.deployTransparentProxy(
            "UniversalNFTCollection.sol:UniversalNFTCollection",
            deployer,
            abi.encodeCall(UniversalNFTCollection.initialize, (deployer, name_, symbol_, config))
        );
        nft = UniversalNFTCollection(proxy);

        saveContract("UniversalNFTCollection", proxy);
        saveContract("UniversalNFTCollection_Implementation", Upgrades.getImplementationAddress(proxy));
        saveContract("UniversalNFTCollection_ProxyAdmin", Upgrades.getAdminAddress(proxy));

        console.log("network:", label);
        console.log("proxy:", proxy);
        console.log("name:", name_);
        console.log("symbol:", symbol_);
        console.log("baseFee:", baseFee);
        console.log("maxBatchSize:", maxBatchSize);
        console.log("supportsBatch:", supportsBatch);
    }

    /// @dev 数值与多链方案一致：主网手续费更高且关闭批量，便宜的链放大 maxBatchSize。
    function _profile(uint256 chainId)
        internal
        pure
        returns (uint256 baseFee, uint256 maxBatchSize, bool supportsBatch, string memory label)
    {
        if (chainId == 1) return (0.01 ether, 10, false, "ETHEREUM");
        if (chainId == 137) return (0.001 ether, 100, true, "POLYGON");
        if (chainId == 56) return (0.001 ether, 50, true, "BSC");
        if (chainId == 42161) return (0.001 ether, 20, true, "ARBITRUM");
        if (chainId == 31337) return (0.001 ether, 20, true, "LOCAL");
        if (chainId == 11_155_111) return (0.0001 ether, 10, true, "SEPOLIA");
        if (chainId == 97) return (0.0001 ether, 50, true, "BSC-TESTNET");
        revert(string.concat("unsupported chainId ", vm.toString(chainId)));
    }
}
