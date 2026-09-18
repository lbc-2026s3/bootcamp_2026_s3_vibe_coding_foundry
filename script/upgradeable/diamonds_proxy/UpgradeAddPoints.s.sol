// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDiamondCut} from "../../../src/upgradeable/diamonds_proxy/interfaces/IDiamondCut.sol";
import {PointsFacet} from "../../../src/upgradeable/diamonds_proxy/facets/PointsFacet.sol";
import {PointsVaultCuts} from "../../../src/upgradeable/diamonds_proxy/libraries/PointsVaultCuts.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice Add `pointsOf` 并 Replace `deposit`，同一钻石地址开始记积分。
/// @dev 钻石地址优先读 `DIAMOND`；未设置则读 `deployments/PointsVaultDiamond/PointsVaultDiamond_<chainId>.json`
contract UpgradeAddPointsScript is BaseScript {
    function run() public broadcaster {
        address diamond = _resolveDiamond();
        address pointsFacet = address(new PointsFacet());
        IDiamondCut(diamond).diamondCut(PointsVaultCuts.addPointsCuts(pointsFacet), address(0), "");

        saveContract("PointsVaultDiamond", diamond);
        saveContract("PointsVault_PointsFacet", pointsFacet);
    }

    function _resolveDiamond() internal view returns (address) {
        try vm.envAddress("DIAMOND") returns (address fromEnv) {
            return fromEnv;
        } catch {
            string memory path = string.concat(
                "deployments/PointsVaultDiamond/PointsVaultDiamond_", vm.toString(block.chainid), ".json"
            );
            return vm.parseJsonAddress(vm.readFile(path), ".address");
        }
    }
}
