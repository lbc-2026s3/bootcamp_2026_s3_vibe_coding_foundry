// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

contract DiamondLoupeFacet is IDiamondLoupe, IERC165 {
    /// @notice 列出钻石上所有 facet，以及每个 facet 挂了哪些 selector（全貌自省）。
    /// @inheritdoc IDiamondLoupe
    function facets() external view returns (Facet[] memory facets_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 selectorCount = ds.selectors.length;
        facets_ = new Facet[](selectorCount);
        uint16[] memory numSelectors = new uint16[](selectorCount);
        uint256 numFacets;
        for (uint256 i; i < selectorCount; i++) {
            bytes4 selector = ds.selectors[i];
            address facetAddress_ = ds.selectorToFacetAndPosition[selector].facetAddress;
            bool found;
            for (uint256 j; j < numFacets; j++) {
                if (facets_[j].facetAddress == facetAddress_) {
                    uint16 count = numSelectors[j];
                    facets_[j].functionSelectors[count] = selector;
                    numSelectors[j]++;
                    found = true;
                    break;
                }
            }
            if (!found) {
                facets_[numFacets].facetAddress = facetAddress_;
                facets_[numFacets].functionSelectors = new bytes4[](selectorCount);
                facets_[numFacets].functionSelectors[0] = selector;
                numSelectors[numFacets] = 1;
                numFacets++;
            }
        }
        for (uint256 i; i < numFacets; i++) {
            uint256 count = numSelectors[i];
            bytes4[] memory selectors_ = new bytes4[](count);
            for (uint256 j; j < count; j++) {
                selectors_[j] = facets_[i].functionSelectors[j];
            }
            facets_[i].functionSelectors = selectors_;
        }
        assembly {
            mstore(facets_, numFacets)
        }
    }

    /// @notice 查询某个 facet 地址当前在钻石上负责的全部 function selector。
    /// @inheritdoc IDiamondLoupe
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 selectorCount = ds.selectors.length;
        uint256 numSelectors;
        facetFunctionSelectors_ = new bytes4[](selectorCount);
        for (uint256 i; i < selectorCount; i++) {
            bytes4 selector = ds.selectors[i];
            if (_facet == ds.selectorToFacetAndPosition[selector].facetAddress) {
                facetFunctionSelectors_[numSelectors] = selector;
                unchecked {
                    numSelectors++;
                }
            }
        }
        assembly {
            mstore(facetFunctionSelectors_, numSelectors)
        }
    }

    /// @notice 去重列出钻石上挂着的所有 facet 合约地址。
    /// @inheritdoc IDiamondLoupe
    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 selectorCount = ds.selectors.length;
        facetAddresses_ = new address[](selectorCount);
        uint256 numFacets;
        for (uint256 i; i < selectorCount; i++) {
            address facetAddress_ = ds.selectorToFacetAndPosition[ds.selectors[i]].facetAddress;
            bool found;
            for (uint256 j; j < numFacets; j++) {
                if (facetAddresses_[j] == facetAddress_) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                facetAddresses_[numFacets] = facetAddress_;
                unchecked {
                    numFacets++;
                }
            }
        }
        assembly {
            mstore(facetAddresses_, numFacets)
        }
    }

    /// @inheritdoc IDiamondLoupe
    function facetAddress(bytes4 _functionSelector) external view returns (address) {
        return LibDiamond.diamondStorage().selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return LibDiamond.diamondStorage().supportedInterfaces[interfaceId];
    }
}
