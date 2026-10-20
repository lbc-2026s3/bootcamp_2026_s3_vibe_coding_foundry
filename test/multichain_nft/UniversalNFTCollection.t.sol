// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC721Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UniversalNFTCollection} from "../../src/multichain_nft/UniversalNFTCollection.sol";

contract UniversalNFTCollectionTest is Test {
    event Minted(address indexed to, uint256 indexed tokenId, uint256 fee);
    event BatchMint(address indexed minter, uint256 indexed firstTokenId, uint256 quantity, uint256 totalFee);
    event FeesWithdrawn(address indexed recipient, uint256 amount);

    UniversalNFTCollection internal nft;
    UniversalNFTCollection internal implementation;
    address internal adminOwner = makeAddr("adminOwner");
    address internal feeRecipient = makeAddr("feeRecipient");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant BASE_FEE = 0.001 ether;

    function setUp() public {
        vm.chainId(137);
        UniversalNFTCollection.ChainConfig memory config = _config(137, BASE_FEE, 3, true, feeRecipient);
        (nft, implementation) = _deploy(config);
        vm.deal(alice, 10 ether);
    }

    function test_Initialize_BindsChainConfig() public view {
        (uint256 chainId, uint256 baseFee, uint256 maxBatchSize, bool supportsBatch, address recipient) =
            nft.chainConfig();
        assertEq(chainId, 137);
        assertEq(baseFee, BASE_FEE);
        assertEq(maxBatchSize, 3);
        assertTrue(supportsBatch);
        assertEq(recipient, feeRecipient);
        assertEq(nft.owner(), adminOwner);
        assertEq(nft.name(), "Universal NFT POLYGON");
        assertEq(nft.symbol(), "UNI-POLYGON");
        assertEq(nft.nextTokenId(), 0);
    }

    function test_RevertWhen_InitializeTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        nft.initialize(adminOwner, "Again", "AGN", _config(137, BASE_FEE, 3, true, feeRecipient));
    }

    function test_RevertWhen_InitializeImplementation() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(adminOwner, "Impl", "IMPL", _config(137, BASE_FEE, 3, true, feeRecipient));
    }

    function test_RevertWhen_ConfigChainDoesNotMatch() public {
        vm.chainId(1);
        UniversalNFTCollection.ChainConfig memory config = _config(137, BASE_FEE, 3, true, feeRecipient);
        UniversalNFTCollection impl = new UniversalNFTCollection();
        vm.expectRevert(abi.encodeWithSelector(UniversalNFTCollection.ChainIdMismatch.selector, 1, 137));
        UnsafeUpgrades.deployTransparentProxy(
            address(impl), adminOwner, abi.encodeCall(UniversalNFTCollection.initialize, (adminOwner, "N", "S", config))
        );
    }

    function test_Mint_ChargesFeeAndRefundsExcess() public {
        uint256 payment = 0.01 ether;
        vm.expectEmit(true, true, false, true, address(nft));
        emit Minted(bob, 0, BASE_FEE);

        vm.prank(alice);
        uint256 tokenId = nft.mint{value: payment}(bob);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(0), bob);
        assertEq(nft.nextTokenId(), 1);
        assertEq(alice.balance, 10 ether - BASE_FEE);
        assertEq(address(nft).balance, BASE_FEE);
    }

    function test_RevertWhen_InsufficientFee() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(UniversalNFTCollection.InsufficientFee.selector, BASE_FEE - 1, BASE_FEE));
        nft.mint{value: BASE_FEE - 1}(bob);
    }

    function test_RevertWhen_MintToZero() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(0)));
        nft.mint{value: BASE_FEE}(address(0));
    }

    function test_BatchMint_MintsRangeAndEmitsOnce() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        vm.expectEmit(true, true, false, true, address(nft));
        emit BatchMint(alice, 0, 2, BASE_FEE * 2);

        vm.prank(alice);
        nft.batchMint{value: BASE_FEE * 2}(recipients);

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.nextTokenId(), 2);
        assertEq(address(nft).balance, BASE_FEE * 2);
    }

    function test_RevertWhen_BatchDisabled() public {
        vm.chainId(1);
        (UniversalNFTCollection mainnet,) = _deploy(_config(1, 0.01 ether, 10, false, feeRecipient));
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(UniversalNFTCollection.BatchNotSupported.selector);
        mainnet.batchMint{value: 0.01 ether}(recipients);

        vm.prank(alice);
        mainnet.mint{value: 0.01 ether}(alice);
        assertEq(mainnet.ownerOf(0), alice);
    }

    function test_RevertWhen_BatchTooLargeOrEmpty() public {
        address[] memory tooMany = new address[](4);
        for (uint256 i = 0; i < tooMany.length; ++i) {
            tooMany[i] = alice;
        }
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(UniversalNFTCollection.BatchLimitExceeded.selector, 4, 3));
        nft.batchMint{value: BASE_FEE * 4}(tooMany);

        address[] memory empty = new address[](0);
        vm.prank(alice);
        vm.expectRevert(UniversalNFTCollection.EmptyBatch.selector);
        nft.batchMint(empty);
    }

    function test_WithdrawFees_SendsBalanceToRecipient() public {
        vm.prank(alice);
        nft.mint{value: BASE_FEE}(alice);

        vm.expectEmit(true, false, false, true, address(nft));
        emit FeesWithdrawn(feeRecipient, BASE_FEE);
        nft.withdrawFees();

        assertEq(feeRecipient.balance, BASE_FEE);
        assertEq(address(nft).balance, 0);

        vm.expectRevert(UniversalNFTCollection.NothingToWithdraw.selector);
        nft.withdrawFees();
    }

    function test_RevertWhen_ReenteringMint() public {
        ReenteringMinter attacker = new ReenteringMinter(nft);
        vm.deal(address(attacker), 1 ether);
        vm.expectRevert(UniversalNFTCollection.ReentrantCall.selector);
        attacker.mint(BASE_FEE);
    }

    function test_SetFeeConfig_OnlyOwnerAndKeepsChainId() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.setFeeConfig(1, 2, true, feeRecipient);

        vm.prank(adminOwner);
        nft.setFeeConfig(0.002 ether, 2, true, alice);

        (uint256 chainId, uint256 baseFee, uint256 maxBatchSize, bool supportsBatch, address recipient) =
            nft.chainConfig();
        assertEq(chainId, 137);
        assertEq(baseFee, 0.002 ether);
        assertEq(maxBatchSize, 2);
        assertTrue(supportsBatch);
        assertEq(recipient, alice);

        vm.prank(alice);
        nft.mint{value: 0.002 ether}(bob);
        assertEq(nft.ownerOf(0), bob);
    }

    function test_TokenURI_UsesBaseAndPerTokenSuffix() public {
        vm.prank(alice);
        nft.mint{value: BASE_FEE}(alice);

        vm.prank(adminOwner);
        nft.setBaseURI("ipfs://base/");
        assertEq(nft.tokenURI(0), "ipfs://base/0");

        vm.prank(adminOwner);
        nft.setTokenURI(0, "custom.json");
        assertEq(nft.tokenURI(0), "ipfs://base/custom.json");
    }

    function test_RevertWhen_ProxyAdminCallsMint() public {
        address proxyAdmin = UnsafeUpgrades.getAdminAddress(address(nft));
        vm.deal(proxyAdmin, BASE_FEE);
        vm.prank(proxyAdmin);
        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        nft.mint{value: BASE_FEE}(alice);
    }

    function testFuzz_RefundsExactFee(uint256 payment) public {
        payment = bound(payment, BASE_FEE, 20 ether);
        vm.deal(alice, payment);
        vm.prank(alice);
        nft.mint{value: payment}(bob);
        assertEq(alice.balance, payment - BASE_FEE);
        assertEq(address(nft).balance, BASE_FEE);
    }

    function _deploy(UniversalNFTCollection.ChainConfig memory config)
        internal
        returns (UniversalNFTCollection proxy, UniversalNFTCollection impl)
    {
        impl = new UniversalNFTCollection();
        address proxyAddr = UnsafeUpgrades.deployTransparentProxy(
            address(impl),
            adminOwner,
            abi.encodeCall(
                UniversalNFTCollection.initialize, (adminOwner, "Universal NFT POLYGON", "UNI-POLYGON", config)
            )
        );
        proxy = UniversalNFTCollection(proxyAddr);
    }

    function _config(uint256 chainId, uint256 baseFee, uint256 maxBatchSize, bool supportsBatch, address recipient)
        internal
        pure
        returns (UniversalNFTCollection.ChainConfig memory)
    {
        return UniversalNFTCollection.ChainConfig({
            chainId: chainId,
            baseFee: baseFee,
            maxBatchSize: maxBatchSize,
            supportsBatch: supportsBatch,
            feeRecipient: recipient
        });
    }
}

contract ReenteringMinter {
    UniversalNFTCollection internal immutable nft;

    constructor(UniversalNFTCollection nft_) {
        nft = nft_;
    }

    function mint(uint256 value) external {
        nft.mint{value: value}(address(this));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        (, uint256 fee,,,) = nft.chainConfig();
        nft.mint{value: fee}(address(this));
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
