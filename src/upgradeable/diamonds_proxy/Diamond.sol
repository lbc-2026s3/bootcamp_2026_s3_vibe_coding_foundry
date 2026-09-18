// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "./interfaces/IDiamondLoupe.sol";
import {IERC173} from "./interfaces/IERC173.sol";
import {LibDiamond} from "./libraries/LibDiamond.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

/// @notice PointsVault 钻石代理：唯一对外地址，fallback 按 selector 路由到 facet。
/// @dev 业务状态在 AppStorage；升级走 diamondCut（Add / Replace / Remove），不是整份 implementation 替换。
contract Diamond {
    error FunctionNotFound(bytes4 selector);

    constructor(address contractOwner, IDiamondCut.FacetCut[] memory cuts) payable {
        LibDiamond.setContractOwner(contractOwner);
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        LibDiamond.diamondCut(cuts, address(0), "");
    }

    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        if (facet == address(0)) revert FunctionNotFound(msg.sig);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /// @dev 禁止裸转 ETH；必须走 `deposit()`，否则余额记账会对不齐。
    receive() external payable {
        revert FunctionNotFound(0x00000000);
    }
}
