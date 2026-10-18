// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// forge script script/EventLab.s.sol --rpc-url local --broadcast \
//   --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
//   && cat ./deployments/LATEST.txt

import {console} from "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.s.sol";
import {EventLab} from "../src/events/EventLab.sol";

contract DeployEventLab is BaseScript {
    function run() public broadcaster {
        EventLab lab = new EventLab();
        saveContract("EventLab", address(lab));
        console.log("EventLab:", address(lab));

        // EventLab lab = EventLab(0x1E1155fAC887b765B3D5Af716C91999Cee6E5B3d);

        lab.emitValueIndexed(lab.SAMPLE_AMOUNT(), deployer, lab.SAMPLE_TAG(), true);
        lab.emitDynamicIndexed(lab.SAMPLE_NOTE(), lab.SAMPLE_BLOB());

        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        lab.emitReferenceIndexed(ids, lab.SAMPLE_ITEM_ID(), lab.SAMPLE_ITEM_NAME());

        lab.emitSample();
    }
}
