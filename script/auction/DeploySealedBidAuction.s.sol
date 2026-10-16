// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ---------------------------------------------------------------------------
// SealedBidAuction — 首价密封拍卖
//
// 部署人就是卖家。提交期 1 小时，披露期 1 小时，保证金 0.01 ETH。
// 承诺公式：keccak256(abi.encode(bidder, bidAmount, secret))
//
// forge script script/auction/DeploySealedBidAuction.s.sol:DeploySealedBidAuction \
//   --broadcast --rpc-url local \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt
// ---------------------------------------------------------------------------

import {console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {SealedBidAuction} from "../../src/auction/SealedBidAuction.sol";

contract DeploySealedBidAuction is BaseScript {
    uint256 internal constant COMMIT_DURATION = 1 hours;
    uint256 internal constant REVEAL_DURATION = 1 hours;
    uint256 internal constant BID_BOND = 0.01 ether;

    SealedBidAuction public auction;

    function run() public broadcaster {
        auction = new SealedBidAuction(COMMIT_DURATION, REVEAL_DURATION, BID_BOND);

        saveContract("SealedBidAuction", address(auction));

        console.log("SealedBidAuction:", address(auction));
        console.log("seller:          ", auction.seller());
        console.log("bid bond:        ", auction.bidBond());
        console.log("commit deadline: ", auction.commitDeadline());
        console.log("reveal deadline: ", auction.revealDeadline());
    }
}
