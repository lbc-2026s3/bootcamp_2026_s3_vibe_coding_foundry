// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";

error NotContractOwner(address user, address contractOwner);
error NoSelectorsGiven();
error NoSelectorsProvidedForFacet(address facetAddress);
error CannotAddSelectorsToZeroAddress(bytes4[] selectors);
error NoBytecodeAtAddress(address contractAddress);
error IncorrectFacetCutAction(uint8 action);
error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 selector);
error CannotReplaceFunctionsFromFacetWithZeroAddress(bytes4[] selectors);
error CannotReplaceImmutableFunction(bytes4 selector);
error CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(bytes4 selector);
error CannotReplaceFunctionThatDoesNotExists(bytes4 selector);
error RemoveFacetAddressMustBeZeroAddress(address facetAddress);
error CannotRemoveFunctionThatDoesNotExist(bytes4 selector);
error CannotRemoveImmutableFunction(bytes4 selector);
error InitializationFunctionReverted(address init, bytes data);

/// @notice EIP-2535 路由表：selector → facet，以及 diamondCut 实现。
/// @dev 使用独立 storage slot，避免与业务 AppStorage / OZ ERC-7201 冲突。
library LibDiamond {
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndSelectorPosition {
        address facetAddress;
        uint16 selectorPosition;
    }

    struct DiamondStorage {
        mapping(bytes4 => FacetAddressAndSelectorPosition) selectorToFacetAndPosition;
        bytes4[] selectors;
        mapping(bytes4 => bool) supportedInterfaces;
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    function enforceIsContractOwner() internal view {
        address owner_ = diamondStorage().contractOwner;
        if (msg.sender != owner_) revert NotContractOwner(msg.sender, owner_);
    }

    function diamondCut(IDiamondCut.FacetCut[] memory _diamondCut, address _init, bytes memory _calldata) internal {
        uint256 n = _diamondCut.length;
        if (n == 0 && _init == address(0)) revert NoSelectorsGiven();
        for (uint256 i; i < n; i++) {
            IDiamondCut.FacetCutAction action = _diamondCut[i].action;
            address facetAddress_ = _diamondCut[i].facetAddress;
            bytes4[] memory selectors_ = _diamondCut[i].functionSelectors;
            if (selectors_.length == 0) revert NoSelectorsProvidedForFacet(facetAddress_);
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(facetAddress_, selectors_);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(facetAddress_, selectors_);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(facetAddress_, selectors_);
            } else {
                revert IncorrectFacetCutAction(uint8(action));
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address facetAddress_, bytes4[] memory selectors_) internal {
        if (facetAddress_ == address(0)) revert CannotAddSelectorsToZeroAddress(selectors_);
        enforceHasContractCode(facetAddress_);
        DiamondStorage storage ds = diamondStorage();
        uint16 selectorCount = uint16(ds.selectors.length);
        for (uint256 i; i < selectors_.length; i++) {
            bytes4 selector = selectors_[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacet != address(0)) revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            // selectorPosition = 该 selector 在 ds.selectors[] 中的下标。
            // Remove 时用它做 O(1) swap-and-pop：把数组末尾元素挪到此下标，再 pop（见 removeFunctions）。
            // Replace 只改 facetAddress，不改 selectorPosition。
            ds.selectorToFacetAndPosition[selector] =
                FacetAddressAndSelectorPosition({facetAddress: facetAddress_, selectorPosition: selectorCount});
            ds.selectors.push(selector);
            unchecked {
                selectorCount++;
            }
        }
    }

    function replaceFunctions(address facetAddress_, bytes4[] memory selectors_) internal {
        if (facetAddress_ == address(0)) revert CannotReplaceFunctionsFromFacetWithZeroAddress(selectors_);
        enforceHasContractCode(facetAddress_);
        DiamondStorage storage ds = diamondStorage();
        for (uint256 i; i < selectors_.length; i++) {
            bytes4 selector = selectors_[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacet == address(this)) revert CannotReplaceImmutableFunction(selector);
            if (oldFacet == facetAddress_) revert CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(selector);
            if (oldFacet == address(0)) revert CannotReplaceFunctionThatDoesNotExists(selector);
            // 给已经注册好的函数选择器（selector）替换新的实现合约地址（facetAddress），不改变其在 ds.selectors[] 中的下标
            ds.selectorToFacetAndPosition[selector].facetAddress = facetAddress_;
        }
    }

    function removeFunctions(address facetAddress_, bytes4[] memory selectors_) internal {
        if (facetAddress_ != address(0)) revert RemoveFacetAddressMustBeZeroAddress(facetAddress_);
        DiamondStorage storage ds = diamondStorage();
        uint256 selectorCount = ds.selectors.length;
        for (uint256 i; i < selectors_.length; i++) {
            bytes4 selector = selectors_[i];
            FacetAddressAndSelectorPosition memory old = ds.selectorToFacetAndPosition[selector];
            if (old.facetAddress == address(0)) revert CannotRemoveFunctionThatDoesNotExist(selector);
            if (old.facetAddress == address(this)) revert CannotRemoveImmutableFunction(selector);
            unchecked {
                selectorCount--;
            }
            // Remove 时用它做 O(1) swap-and-pop：把数组末尾元素挪到此下标，再 pop（见 removeFunctions）。
            if (old.selectorPosition != selectorCount) {
                bytes4 lastSelector = ds.selectors[selectorCount];
                ds.selectors[old.selectorPosition] = lastSelector;
                ds.selectorToFacetAndPosition[lastSelector].selectorPosition = old.selectorPosition;
            }
            ds.selectors.pop();
            delete ds.selectorToFacetAndPosition[selector];
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) return;
        enforceHasContractCode(_init);
        (bool success, bytes memory err) = _init.delegatecall(_calldata);
        if (!success) {
            if (err.length > 0) {
                assembly {
                    revert(add(err, 32), mload(err))
                }
            }
            revert InitializationFunctionReverted(_init, _calldata);
        }
    }

    function enforceHasContractCode(address contractAddress) internal view {
        uint256 size;
        assembly {
            size := extcodesize(contractAddress)
        }
        if (size == 0) revert NoBytecodeAtAddress(contractAddress);
    }
}
