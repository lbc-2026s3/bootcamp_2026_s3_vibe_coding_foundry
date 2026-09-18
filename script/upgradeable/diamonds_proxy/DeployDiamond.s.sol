// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Diamond} from "../../../src/upgradeable/diamonds_proxy/Diamond.sol";
import {DiamondCutFacet} from "../../../src/upgradeable/diamonds_proxy/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../../src/upgradeable/diamonds_proxy/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../../src/upgradeable/diamonds_proxy/facets/OwnershipFacet.sol";
import {VaultFacet} from "../../../src/upgradeable/diamonds_proxy/facets/VaultFacet.sol";
import {PointsVaultCuts} from "../../../src/upgradeable/diamonds_proxy/libraries/PointsVaultCuts.sol";
import {BaseScript} from "../../BaseScript.s.sol";

/// @notice 部署 PointsVault Diamond（Cut / Loupe / Ownership / Vault V1）。
contract DeployDiamondScript is BaseScript {
    function run() public broadcaster {
        address cutFacet = address(new DiamondCutFacet());
        address loupeFacet = address(new DiamondLoupeFacet());
        address ownershipFacet = address(new OwnershipFacet());
        address vaultFacet = address(new VaultFacet());
        Diamond diamond = new Diamond(deployer, PointsVaultCuts.v1Cuts(cutFacet, loupeFacet, ownershipFacet, vaultFacet));

        saveContract("PointsVaultDiamond", address(diamond));
        saveContract("PointsVault_DiamondCutFacet", cutFacet);
        saveContract("PointsVault_DiamondLoupeFacet", loupeFacet);
        saveContract("PointsVault_OwnershipFacet", ownershipFacet);
        saveContract("PointsVault_VaultFacet", vaultFacet);
    }
}
