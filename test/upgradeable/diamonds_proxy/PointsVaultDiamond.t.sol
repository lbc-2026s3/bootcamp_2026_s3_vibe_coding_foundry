// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {Diamond} from "../../../src/upgradeable/diamonds_proxy/Diamond.sol";
import {DiamondCutFacet} from "../../../src/upgradeable/diamonds_proxy/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../../src/upgradeable/diamonds_proxy/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../../src/upgradeable/diamonds_proxy/facets/OwnershipFacet.sol";
import {VaultFacet} from "../../../src/upgradeable/diamonds_proxy/facets/VaultFacet.sol";
import {VaultFacetV2} from "../../../src/upgradeable/diamonds_proxy/facets/VaultFacetV2.sol";
import {PointsFacet} from "../../../src/upgradeable/diamonds_proxy/facets/PointsFacet.sol";
import {ExperimentalFacet} from "../../../src/upgradeable/diamonds_proxy/facets/ExperimentalFacet.sol";
import {VaultV2Init, AlreadyInitialized, InvalidFeeBps} from "../../../src/upgradeable/diamonds_proxy/inits/VaultV2Init.sol";
import {IDiamondCut} from "../../../src/upgradeable/diamonds_proxy/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../../src/upgradeable/diamonds_proxy/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../../../src/upgradeable/diamonds_proxy/interfaces/IERC173.sol";
import {IVault} from "../../../src/upgradeable/diamonds_proxy/interfaces/IVault.sol";
import {IVaultV2} from "../../../src/upgradeable/diamonds_proxy/interfaces/IVaultV2.sol";
import {IPoints} from "../../../src/upgradeable/diamonds_proxy/interfaces/IPoints.sol";
import {IExperimental} from "../../../src/upgradeable/diamonds_proxy/interfaces/IExperimental.sol";
import {PointsVaultCuts} from "../../../src/upgradeable/diamonds_proxy/libraries/PointsVaultCuts.sol";
import {
    NotContractOwner,
    CannotAddFunctionToDiamondThatAlreadyExists,
    CannotReplaceFunctionThatDoesNotExists
} from "../../../src/upgradeable/diamonds_proxy/libraries/LibDiamond.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

contract PointsVaultDiamondTest is Test {
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal stranger = makeAddr("stranger");

    Diamond internal diamond;
    address internal cutFacet;
    address internal loupeFacet;
    address internal ownershipFacet;
    address internal vaultFacet;

    IDiamondCut internal cut;
    IDiamondLoupe internal loupe;
    IERC173 internal ownership;
    IVault internal vault;

    function setUp() public {
        cutFacet = address(new DiamondCutFacet());
        loupeFacet = address(new DiamondLoupeFacet());
        ownershipFacet = address(new OwnershipFacet());
        vaultFacet = address(new VaultFacet());

        diamond = new Diamond(owner, PointsVaultCuts.v1Cuts(cutFacet, loupeFacet, ownershipFacet, vaultFacet));
        cut = IDiamondCut(address(diamond));
        loupe = IDiamondLoupe(address(diamond));
        ownership = IERC173(address(diamond));
        vault = IVault(address(diamond));

        vm.deal(alice, 100 ether);
    }

    function test_DepositWithdraw_StateLivesOnDiamond() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        assertEq(vault.balanceOf(alice), 1 ether);
        assertEq(vault.totalDeposits(), 1 ether);
        assertEq(address(diamond).balance, 1 ether);
        // facet 只提供逻辑；delegatecall 把 ETH / 存储写在钻石上，facet 合约自身余额应为 0
        assertEq(vaultFacet.balance, 0);

        uint256 before = alice.balance;
        vm.prank(alice);
        vault.withdraw(0.4 ether);

        assertEq(vault.balanceOf(alice), 0.6 ether);
        assertEq(alice.balance, before + 0.4 ether);
        assertEq(address(diamond).balance, 0.6 ether);
    }

    function test_Loupe_RoutesDepositToVaultFacet() public view {
        assertEq(loupe.facetAddress(IVault.deposit.selector), vaultFacet);
        assertEq(loupe.facetAddress(IDiamondCut.diamondCut.selector), cutFacet);
        assertEq(ownership.owner(), owner);
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IDiamondLoupe).interfaceId));
    }

    function test_AddPoints_ThenNewDepositsAccrue_OldBalanceKept() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        PointsFacet pointsImpl = new PointsFacet();
        vm.prank(owner);
        cut.diamondCut(PointsVaultCuts.addPointsCuts(address(pointsImpl)), address(0), "");

        IPoints points = IPoints(address(diamond));
        assertEq(loupe.facetAddress(IPoints.pointsOf.selector), address(pointsImpl));
        assertEq(loupe.facetAddress(IVault.deposit.selector), address(pointsImpl));
        assertEq(points.pointsOf(alice), 0);
        assertEq(vault.balanceOf(alice), 2 ether);

        vm.prank(alice);
        vault.deposit{value: 1 ether}();
        assertEq(vault.balanceOf(alice), 3 ether);
        assertEq(points.pointsOf(alice), 1 ether);
    }

    function test_ReplaceWithdraw_AppliesFee_KeepsPoints() public {
        PointsFacet pointsImpl = new PointsFacet();
        vm.prank(owner);
        cut.diamondCut(PointsVaultCuts.addPointsCuts(address(pointsImpl)), address(0), "");

        vm.prank(alice);
        vault.deposit{value: 1 ether}();
        assertEq(IPoints(address(diamond)).pointsOf(alice), 1 ether);

        _upgradeVaultV2(100);

        assertEq(IVaultV2(address(diamond)).withdrawFeeBps(), 100);
        assertEq(loupe.facetAddress(IVault.withdraw.selector) == vaultFacet, false);

        uint256 before = alice.balance;
        vm.prank(alice);
        vault.withdraw(1 ether);

        uint256 fee = 0.01 ether;
        assertEq(alice.balance, before + 1 ether - fee);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(IVaultV2(address(diamond)).protocolFees(), fee);
        assertEq(address(diamond).balance, fee);
        // V2 后：合约 ETH = 用户记账余额合计 + 协议手续费
        assertEq(address(diamond).balance, vault.totalDeposits() + fee);
        assertEq(IPoints(address(diamond)).pointsOf(alice), 1 ether);
    }

    function test_RemoveExperimentalSelector() public {
        ExperimentalFacet experimental = new ExperimentalFacet();
        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(experimental),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: PointsVaultCuts.experimentalSelectors()
        });
        vm.prank(owner);
        cut.diamondCut(addCuts, address(0), "");

        assertEq(IExperimental(address(diamond)).ping(), keccak256("pong"));

        vm.prank(owner);
        cut.diamondCut(
            PointsVaultCuts.one(address(0), IDiamondCut.FacetCutAction.Remove, IExperimental.ping.selector).toArray(),
            address(0),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(Diamond.FunctionNotFound.selector, IExperimental.ping.selector));
        IExperimental(address(diamond)).ping();
        assertEq(loupe.facetAddress(IExperimental.ping.selector), address(0));
    }

    function test_RemoveMiddleSelector_KeepsNeighbors() public {
        // deposit 在 V1 表中间位置；Remove 它必须走 swap-and-pop，不能弄坏 withdraw / balanceOf。
        assertEq(loupe.facetAddress(IVault.deposit.selector), vaultFacet);
        assertEq(loupe.facetAddress(IVault.withdraw.selector), vaultFacet);

        vm.prank(owner);
        cut.diamondCut(
            PointsVaultCuts.one(address(0), IDiamondCut.FacetCutAction.Remove, IVault.deposit.selector).toArray(),
            address(0),
            ""
        );

        assertEq(loupe.facetAddress(IVault.deposit.selector), address(0));
        assertEq(loupe.facetAddress(IVault.withdraw.selector), vaultFacet);
        assertEq(loupe.facetAddress(IVault.balanceOf.selector), vaultFacet);
        assertEq(loupe.facetAddress(IVault.totalDeposits.selector), vaultFacet);

        vm.deal(alice, 1 ether);
        // 无法再 deposit；已有余额路径：先直接给钻石 ETH 并无法记账——这里只测 withdraw 路由仍有效：
        // 用 Points Add 再挂回 deposit，确认其它 selector 未被破坏。
        PointsFacet pointsImpl = new PointsFacet();
        IDiamondCut.FacetCut[] memory cuts_ = new IDiamondCut.FacetCut[](1);
        cuts_[0] = PointsVaultCuts.one(address(pointsImpl), IDiamondCut.FacetCutAction.Add, IVault.deposit.selector);
        vm.prank(owner);
        cut.diamondCut(cuts_, address(0), "");

        vm.prank(alice);
        vault.deposit{value: 1 ether}();
        vm.prank(alice);
        vault.withdraw(1 ether);
        assertEq(vault.balanceOf(alice), 0);
    }

    function test_RevertWhen_NonOwnerDiamondCut() public {
        PointsFacet pointsImpl = new PointsFacet();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(NotContractOwner.selector, stranger, owner));
        cut.diamondCut(PointsVaultCuts.addPointsCuts(address(pointsImpl)), address(0), "");
    }

    function test_RevertWhen_AddExistingSelector() public {
        IDiamondCut.FacetCut[] memory cuts_ = new IDiamondCut.FacetCut[](1);
        cuts_[0] = PointsVaultCuts.one(vaultFacet, IDiamondCut.FacetCutAction.Add, IVault.deposit.selector);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(CannotAddFunctionToDiamondThatAlreadyExists.selector, IVault.deposit.selector));
        cut.diamondCut(cuts_, address(0), "");
    }

    function test_RevertWhen_ReplaceMissingSelector() public {
        VaultFacetV2 v2 = new VaultFacetV2();
        IDiamondCut.FacetCut[] memory cuts_ = new IDiamondCut.FacetCut[](1);
        cuts_[0] = PointsVaultCuts.one(address(v2), IDiamondCut.FacetCutAction.Replace, IPoints.pointsOf.selector);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(CannotReplaceFunctionThatDoesNotExists.selector, IPoints.pointsOf.selector));
        cut.diamondCut(cuts_, address(0), "");
    }

    function test_RevertWhen_WithdrawMoreThanBalance() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();
        vm.prank(alice);
        vm.expectRevert(IVault.InsufficientBalance.selector);
        vault.withdraw(2 ether);
    }

    function test_RevertWhen_DepositZero() public {
        vm.prank(alice);
        vm.expectRevert(IVault.ZeroAmount.selector);
        vault.deposit{value: 0}();
    }

    function test_RevertWhen_ReceiveBareEth() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Diamond.FunctionNotFound.selector, bytes4(0)));
        (bool ok,) = address(diamond).call{value: 1 ether}("");
        ok;
    }

    function test_RevertWhen_InitV2Twice() public {
        _upgradeVaultV2(100);
        VaultV2Init init2 = new VaultV2Init();
        vm.prank(owner);
        vm.expectRevert(AlreadyInitialized.selector);
        cut.diamondCut(new IDiamondCut.FacetCut[](0), address(init2), abi.encodeCall(VaultV2Init.init, (50)));
    }

    function test_RevertWhen_InvalidFeeBps() public {
        VaultFacetV2 v2 = new VaultFacetV2();
        VaultV2Init init_ = new VaultV2Init();
        vm.prank(owner);
        vm.expectRevert(InvalidFeeBps.selector);
        cut.diamondCut(
            PointsVaultCuts.replaceVaultV2Cuts(address(v2)), address(init_), abi.encodeCall(VaultV2Init.init, (1_001))
        );
    }

    function testFuzz_DepositWithdrawRoundtrip(uint96 amount) public {
        amount = uint96(bound(amount, 1, 50 ether));
        vm.prank(alice);
        vault.deposit{value: amount}();
        uint256 before = alice.balance;
        vm.prank(alice);
        vault.withdraw(amount);
        assertEq(alice.balance, before + amount);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(address(diamond).balance, 0);
    }

    function testFuzz_WithdrawFeeMatchesBps(uint96 amount, uint16 feeBps) public {
        amount = uint96(bound(amount, 1, 50 ether));
        feeBps = uint16(bound(feeBps, 0, 1_000));
        _upgradeVaultV2(feeBps);

        vm.prank(alice);
        vault.deposit{value: amount}();
        uint256 fee = (uint256(amount) * feeBps) / 10_000;
        uint256 before = alice.balance;
        vm.prank(alice);
        vault.withdraw(amount);
        assertEq(alice.balance, before + amount - fee);
        assertEq(IVaultV2(address(diamond)).protocolFees(), fee);
        assertEq(address(diamond).balance, fee);
    }

    function _upgradeVaultV2(uint256 feeBps) internal {
        VaultFacetV2 v2 = new VaultFacetV2();
        VaultV2Init init_ = new VaultV2Init();
        vm.prank(owner);
        cut.diamondCut(
            PointsVaultCuts.replaceVaultV2Cuts(address(v2)), address(init_), abi.encodeCall(VaultV2Init.init, (feeBps))
        );
    }
}

library FacetCutExt {
    function toArray(IDiamondCut.FacetCut memory cut) internal pure returns (IDiamondCut.FacetCut[] memory cuts) {
        cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = cut;
    }
}

using FacetCutExt for IDiamondCut.FacetCut;
