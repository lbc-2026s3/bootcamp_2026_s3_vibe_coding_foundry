// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IVaultV2} from "../interfaces/IVaultV2.sol";
import {IPoints} from "../interfaces/IPoints.sol";
import {IExperimental} from "../interfaces/IExperimental.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

/// @notice 组装 FacetCut / selector 列表，测试与部署脚本共用。
library PointsVaultCuts {
    function one(address facet, IDiamondCut.FacetCutAction action, bytes4 selector)
        internal
        pure
        returns (IDiamondCut.FacetCut memory cut)
    {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = selector;
        cut = IDiamondCut.FacetCut({facetAddress: facet, action: action, functionSelectors: selectors});
    }

    function cutSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](1);
        s[0] = IDiamondCut.diamondCut.selector;
    }

    function loupeSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](5);
        s[0] = IDiamondLoupe.facets.selector;
        s[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        s[2] = IDiamondLoupe.facetAddresses.selector;
        s[3] = IDiamondLoupe.facetAddress.selector;
        s[4] = IERC165.supportsInterface.selector;
    }

    function ownershipSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](2);
        s[0] = IERC173.owner.selector;
        s[1] = IERC173.transferOwnership.selector;
    }

    function vaultV1Selectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](4);
        s[0] = IVault.deposit.selector;
        s[1] = IVault.withdraw.selector;
        s[2] = IVault.balanceOf.selector;
        s[3] = IVault.totalDeposits.selector;
    }

    function pointsAddSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](1);
        s[0] = IPoints.pointsOf.selector;
    }

    function vaultV2AddSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](2);
        s[0] = IVaultV2.withdrawFeeBps.selector;
        s[1] = IVaultV2.protocolFees.selector;
    }

    function experimentalSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](1);
        s[0] = IExperimental.ping.selector;
    }

    function v1Cuts(address cutFacet, address loupeFacet, address ownershipFacet, address vaultFacet)
        internal
        pure
        returns (IDiamondCut.FacetCut[] memory cuts)
    {
        cuts = new IDiamondCut.FacetCut[](4);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: cutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors()
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: loupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors()
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: ownershipFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors()
        });
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: vaultFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: vaultV1Selectors()
        });
    }

    function addPointsCuts(address pointsFacet) internal pure returns (IDiamondCut.FacetCut[] memory cuts) {
        cuts = new IDiamondCut.FacetCut[](2);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: pointsFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: pointsAddSelectors()
        });
        cuts[1] = one(pointsFacet, IDiamondCut.FacetCutAction.Replace, IVault.deposit.selector);
    }

    function replaceVaultV2Cuts(address vaultFacetV2) internal pure returns (IDiamondCut.FacetCut[] memory cuts) {
        cuts = new IDiamondCut.FacetCut[](2);
        cuts[0] = one(vaultFacetV2, IDiamondCut.FacetCutAction.Replace, IVault.withdraw.selector);
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: vaultFacetV2,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: vaultV2AddSelectors()
        });
    }
}
