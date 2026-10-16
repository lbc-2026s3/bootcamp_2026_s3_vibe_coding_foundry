// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// 泄漏地址抢救：环境准备
//
// 部署 LabERC20、LabNFT、RescueDelegate，并给受害者铸造资产。
// 不转移资产。转移在 RescueCompromisedWallet.s.sol。
//
// 私钥只从 .env 读取（Foundry 会自动加载项目根目录的 .env）：
//   RESCUE_SPONSOR_KEY  赞助者。支付 gas，也是资产接收地址。Sepolia 上需要有 ETH。
//   RESCUE_VICTIM_KEY   受害者。只用于算出地址，本脚本不拿它签名。余额必须是 0。
//
// 本地 anvil（另开终端先执行 anvil）：
// forge script script/rescue/PrepareRescueEnv.s.sol:PrepareRescueEnv \
//   --broadcast --rpc-url local \
//   && cat ./deployments/LATEST.txt
//
// Sepolia：Forge 的原始估算大约只有节点 eth_estimateGas 的 1/7。
// 乘数是相对 100 的百分比，800 即 8 倍。NFT 部署大约 1440 万 gas，低于单笔上限 16777216。
// forge script script/rescue/PrepareRescueEnv.s.sol:PrepareRescueEnv \
//   --broadcast --rpc-url sepolia --gas-estimate-multiplier 800 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {LabERC20, LabNFT} from "../../src/rescue/LabAssets.sol";
import {RescueDelegate} from "../../src/rescue/RescueDelegate.sol";
import {RescuePlan} from "./RescuePlan.sol";

contract PrepareRescueEnv is BaseScript {
    LabERC20 public token;
    LabNFT public nft;
    RescueDelegate public delegate;

    function run() public broadcasterWith(vm.envUint("RESCUE_SPONSOR_KEY")) {
        require(block.chainid != 1, "mainnet is refused");

        address victim = vm.addr(vm.envUint("RESCUE_VICTIM_KEY"));
        // startBroadcast 只决定哪把私钥签名。脚本执行时的 msg.sender 仍可能是 Foundry 默认地址，
        // 所以收款地址必须用环境变量里的私钥推导，不能读 msg.sender。
        address sponsor = vm.addr(vm.envUint("RESCUE_SPONSOR_KEY"));
        require(sponsor != victim, "sponsor and victim must differ");
        require(sponsor.balance > 0, "sponsor needs ETH for gas");
        require(victim.balance == 0, "victim must start with 0 ETH");

        token = new LabERC20();
        nft = new LabNFT();
        delegate = new RescueDelegate(sponsor);

        uint256 amount = 100 * 10 ** token.decimals();
        token.mint(victim, amount);

        uint256[] memory ids = new uint256[](3);
        ids[0] = nft.mint(victim);
        ids[1] = nft.mint(victim);
        ids[2] = nft.mint(victim);

        saveContract("LabERC20", address(token));
        saveContract("LabNFT", address(nft));
        saveContract("RescueDelegate", address(delegate));

        RescuePlan.store(
            RescuePlan.Data({
                victim: victim,
                sponsor: sponsor,
                token: address(token),
                nft: address(nft),
                delegate: address(delegate),
                amount: amount,
                tokenIds: ids
            })
        );

        console.log("chainId:          ", block.chainid);
        console.log("victim (0 ETH):   ", victim);
        console.log("sponsor:          ", sponsor);
        console.log("LabERC20:         ", address(token));
        console.log("LabNFT:           ", address(nft));
        console.log("RescueDelegate:   ", address(delegate));
        console.log("LAB raw amount:   ", amount);
        console.log("NFT ids:          ", ids[0], ids[1], ids[2]);
    }
}
