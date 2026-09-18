// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDiamondCut} from "../../../src/upgradeable/diamonds_proxy/interfaces/IDiamondCut.sol";
import {VaultFacetV2} from "../../../src/upgradeable/diamonds_proxy/facets/VaultFacetV2.sol";
import {VaultV2Init} from "../../../src/upgradeable/diamonds_proxy/inits/VaultV2Init.sol";
import {PointsVaultCuts} from "../../../src/upgradeable/diamonds_proxy/libraries/PointsVaultCuts.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice Replace `withdraw` 为带手续费版本，并通过 init delegatecall 写入 1% 费率。
/// @dev 钻石地址优先读 `DIAMOND`；未设置则读 `deployments/PointsVaultDiamond/PointsVaultDiamond_<chainId>.json`
contract UpgradeReplaceVaultScript is BaseScript {
    uint256 public constant FEE_BPS = 100;

    function run() public broadcaster {
        address diamond = _resolveDiamond();
        address vaultFacetV2 = address(new VaultFacetV2());
        address init_ = address(new VaultV2Init());
        IDiamondCut(diamond).diamondCut(
            PointsVaultCuts.replaceVaultV2Cuts(vaultFacetV2), init_, abi.encodeCall(VaultV2Init.init, (FEE_BPS))
        );

        saveContract("PointsVaultDiamond", diamond);
        saveContract("PointsVault_VaultFacetV2", vaultFacetV2);
        saveContract("PointsVault_VaultV2Init", init_);
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
