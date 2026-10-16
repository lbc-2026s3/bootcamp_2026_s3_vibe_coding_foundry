// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// 泄漏地址抢救：营救
//
// 先跑 PrepareRescueEnv，它会写下 deployments/RescuePlan/RescuePlan_<chainId>.json。
// 本脚本不部署合约。赞助者支付 gas，受害者只提供 EIP-7702 签名。
//
// 私钥只从 .env 读取：
//   RESCUE_SPONSOR_KEY  必须是准备脚本里的赞助者，也是 RescueDelegate 的收款地址。
//   RESCUE_VICTIM_KEY   必须是准备脚本里的受害者。
//
// 本地 anvil：
// forge script script/rescue/RescueCompromisedWallet.s.sol:RescueCompromisedWallet \
//   --broadcast --rpc-url local
//
// Sepolia：
// forge script script/rescue/RescueCompromisedWallet.s.sol:RescueCompromisedWallet \
//   --broadcast --rpc-url sepolia --gas-estimate-multiplier 800
// ---------------------------------------------------------------------------

import {Script, console} from "forge-std/Script.sol";
import {LabERC20, LabNFT} from "../../src/rescue/LabAssets.sol";
import {RescueDelegate} from "../../src/rescue/RescueDelegate.sol";
import {RescuePlan} from "./RescuePlan.sol";

contract RescueCompromisedWallet is Script {
    function run() public {
        require(block.chainid != 1, "mainnet is refused");

        uint256 sponsorKey = vm.envUint("RESCUE_SPONSOR_KEY");
        uint256 victimKey = vm.envUint("RESCUE_VICTIM_KEY");
        address sponsor = vm.addr(sponsorKey);
        address victim = vm.addr(victimKey);

        RescuePlan.Data memory plan = RescuePlan.load();
        require(plan.sponsor == sponsor, "sponsor key does not match plan");
        require(plan.victim == victim, "victim key does not match plan");
        require(RescueDelegate(plan.delegate).safe() == sponsor, "delegate safe is not sponsor");
        require(sponsor.balance > 0, "sponsor needs ETH for gas");

        LabERC20 token = LabERC20(plan.token);
        LabNFT nft = LabNFT(plan.nft);
        uint256 amount = token.balanceOf(victim);
        require(amount == plan.amount, "victim LAB balance changed");
        require(plan.tokenIds.length == 3, "expected 3 NFTs");
        require(nft.ownerOf(plan.tokenIds[0]) == victim, "NFT 1 not on victim");
        require(nft.ownerOf(plan.tokenIds[1]) == victim, "NFT 2 not on victim");
        require(nft.ownerOf(plan.tokenIds[2]) == victim, "NFT 3 not on victim");

        console.log("chainId:          ", block.chainid);
        console.log("victim:           ", victim);
        console.log("sponsor:          ", sponsor);
        console.log("LAB raw amount:   ", amount);

        vm.startBroadcast(sponsorKey);
        // 受害者私钥只用来签 EIP-7702 授权：把受害者地址上的代码指向 RescueDelegate。
        // 授权附在下一笔交易上。受害者余额是 0，自己发不出交易。
        vm.signAndAttachDelegation(plan.delegate, victimKey);
        // 这笔交易由赞助者发出并支付 gas，调用目标是受害者地址。
        // 执行 RescueDelegate.rescue 时 address(this) 是受害者，LAB 和 NFT 从受害者转出。
        // msg.sender 仍是赞助者，合约只允许转到构造时写死的赞助者。
        RescueDelegate(victim).rescue(plan.token, amount, plan.nft, plan.tokenIds);
        vm.stopBroadcast();

        require(victim.balance == 0, "victim ETH changed");
        require(token.balanceOf(victim) == 0, "LAB left on victim");
        require(token.balanceOf(sponsor) == amount, "LAB did not reach sponsor");
        require(nft.ownerOf(plan.tokenIds[0]) == sponsor, "NFT 1 did not reach sponsor");
        require(nft.ownerOf(plan.tokenIds[1]) == sponsor, "NFT 2 did not reach sponsor");
        require(nft.ownerOf(plan.tokenIds[2]) == sponsor, "NFT 3 did not reach sponsor");

        console.log("victim ETH after: ", victim.balance);
        console.log("sponsor LAB after:", token.balanceOf(sponsor));
        console.log("NFT 1 owner:      ", nft.ownerOf(plan.tokenIds[0]));
    }
}
