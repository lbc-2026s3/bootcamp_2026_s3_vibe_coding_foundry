// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MemeFactory} from "../src/MemeFactory.sol";
import {MemeToken} from "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory internal factory;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant MAX_SUPPLY = 1_000e18;
    uint256 internal constant PER_MINT = 100e18;

    function setUp() public {
        factory = new MemeFactory();
    }

    function _deploy(address creator, string memory symbol, uint256 totalSupply, uint256 perMint)
        private
        returns (MemeToken)
    {
        vm.prank(creator);
        return MemeToken(factory.deployInscription(symbol, totalSupply, perMint));
    }

    /// @dev 从 EIP-1167 最小代理的 runtime bytecode 里抠出 implementation 地址。
    ///      45 字节布局: [10 字节前缀][20 字节 impl][15 字节后缀]。
    ///      Solidity 的 `bytes` 在 memory 里是 32 字节 length 头 + 数据,所以 impl 从 `code+32+10 = code+42` 开始。
    ///      `mload` 一次读 32 字节(20 字节地址 + 后面 12 字节后缀),`shr(96)` 丢掉那 12 字节,剩下 160 位地址。
    function _cloneImplementation(address clone) private view returns (address impl) {
        bytes memory code = clone.code;
        require(code.length == 45, "not eip-1167 runtime");
        assembly {
            impl := shr(96, mload(add(code, 42)))
        }
    }

    function test_DeployInscription_UsesMinimalProxy() public {
        MemeToken token = _deploy(alice, "DOGE", MAX_SUPPLY, PER_MINT);

        assertEq(address(token).code.length, 45);
        assertEq(_cloneImplementation(address(token)), factory.implementation());
        assertTrue(factory.isInscription(address(token)));
        assertEq(token.factory(), address(factory));
        assertEq(token.creator(), alice);
        assertEq(token.symbol(), "DOGE");
        assertEq(token.name(), "DOGE");
        assertEq(token.decimals(), 18);
        assertEq(token.maxSupply(), MAX_SUPPLY);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.totalSupply(), 0);
    }

    function test_DeployInscription_EmitsEvent() public {
        vm.expectEmit(false, true, false, true);
        emit MemeFactory.InscriptionDeployed(address(0), alice, "DOGE", MAX_SUPPLY, PER_MINT);

        vm.prank(alice);
        factory.deployInscription("DOGE", MAX_SUPPLY, PER_MINT);
    }

    function test_DeployInscription_DifferentClonesShareImplementation() public {
        MemeToken a = _deploy(alice, "DOGE", MAX_SUPPLY, PER_MINT);
        MemeToken b = _deploy(bob, "PEPE", 500e18, 50e18);

        assertTrue(address(a) != address(b));
        assertEq(keccak256(address(a).code), keccak256(address(b).code));
        assertEq(a.symbol(), "DOGE");
        assertEq(b.symbol(), "PEPE");
        assertEq(a.creator(), alice);
        assertEq(b.creator(), bob);
    }

    function test_RevertWhen_EmptySymbol() public {
        vm.expectRevert(MemeFactory.EmptySymbol.selector);
        factory.deployInscription("", MAX_SUPPLY, PER_MINT);
    }

    function test_RevertWhen_InvalidSupply() public {
        vm.expectRevert(MemeFactory.InvalidSupply.selector);
        factory.deployInscription("DOGE", 0, PER_MINT);

        vm.expectRevert(MemeFactory.InvalidSupply.selector);
        factory.deployInscription("DOGE", MAX_SUPPLY, 0);

        vm.expectRevert(MemeFactory.InvalidSupply.selector);
        factory.deployInscription("DOGE", PER_MINT, MAX_SUPPLY);
    }

    function test_MintInscription_MintsPerMintToCaller() public {
        MemeToken token = _deploy(alice, "DOGE", MAX_SUPPLY, PER_MINT);

        vm.expectEmit(true, true, false, true);
        emit MemeFactory.InscriptionMinted(address(token), bob, PER_MINT);

        vm.prank(bob);
        factory.mintInscription(address(token));

        assertEq(token.balanceOf(bob), PER_MINT);
        assertEq(token.totalSupply(), PER_MINT);
    }

    function test_MintInscription_StopsAtCap() public {
        uint256 maxSupply = 250e18;
        uint256 perMint = 100e18;
        MemeToken token = _deploy(alice, "DOGE", maxSupply, perMint);

        vm.prank(alice);
        factory.mintInscription(address(token));
        vm.prank(bob);
        factory.mintInscription(address(token));

        assertEq(token.totalSupply(), 200e18);

        vm.prank(alice);
        vm.expectRevert(MemeToken.CapExceeded.selector);
        factory.mintInscription(address(token));

        assertEq(token.totalSupply(), 200e18);
        assertEq(token.balanceOf(alice), perMint);
        assertEq(token.balanceOf(bob), perMint);
    }

    function test_MintInscription_ExactCap() public {
        MemeToken token = _deploy(alice, "DOGE", PER_MINT, PER_MINT);

        vm.prank(bob);
        factory.mintInscription(address(token));

        assertEq(token.totalSupply(), PER_MINT);

        vm.prank(bob);
        vm.expectRevert(MemeToken.CapExceeded.selector);
        factory.mintInscription(address(token));
    }

    function test_RevertWhen_MintUnknownToken() public {
        vm.expectRevert(MemeFactory.UnknownInscription.selector);
        factory.mintInscription(address(0x1234));
    }

    function test_RevertWhen_MintImplementation() public {
        address impl = factory.implementation();
        vm.expectRevert(MemeFactory.UnknownInscription.selector);
        factory.mintInscription(impl);
    }

    function test_RevertWhen_DirectMintBypassesFactory() public {
        MemeToken token = _deploy(alice, "DOGE", MAX_SUPPLY, PER_MINT);

        vm.prank(bob);
        vm.expectRevert(MemeToken.NotFactory.selector);
        token.mint(bob);
    }

    function test_RevertWhen_InitializeImplementation() public {
        MemeToken impl = MemeToken(factory.implementation());

        vm.prank(address(factory));
        vm.expectRevert(MemeToken.AlreadyInitialized.selector);
        impl.initialize(alice, "X", MAX_SUPPLY, PER_MINT);
    }

    function test_RevertWhen_ReinitializeClone() public {
        MemeToken token = _deploy(alice, "DOGE", MAX_SUPPLY, PER_MINT);

        vm.prank(address(factory));
        vm.expectRevert(MemeToken.AlreadyInitialized.selector);
        token.initialize(bob, "HACK", 1, 1);
    }

    function test_Token_TransferAndApprove() public {
        MemeToken token = _deploy(alice, "DOGE", MAX_SUPPLY, PER_MINT);

        vm.prank(alice);
        factory.mintInscription(address(token));

        vm.prank(alice);
        token.transfer(bob, 40e18);
        assertEq(token.balanceOf(alice), 60e18);
        assertEq(token.balanceOf(bob), 40e18);

        vm.prank(bob);
        token.approve(alice, 10e18);
        vm.prank(alice);
        token.transferFrom(bob, alice, 10e18);
        assertEq(token.balanceOf(alice), 70e18);
        assertEq(token.balanceOf(bob), 30e18);
        assertEq(token.allowance(bob, alice), 0);
    }

    function test_IsolatedSuppliesAcrossClones() public {
        MemeToken doge = _deploy(alice, "DOGE", MAX_SUPPLY, PER_MINT);
        MemeToken pepe = _deploy(bob, "PEPE", 50e18, 10e18);

        vm.prank(alice);
        factory.mintInscription(address(doge));
        vm.prank(bob);
        factory.mintInscription(address(pepe));

        assertEq(doge.totalSupply(), PER_MINT);
        assertEq(pepe.totalSupply(), 10e18);
        assertEq(doge.balanceOf(alice), PER_MINT);
        assertEq(pepe.balanceOf(bob), 10e18);
        assertEq(doge.balanceOf(bob), 0);
    }

    function testFuzz_MintNeverExceedsCap(uint256 perMint, uint8 completeMints, uint256 remainder) public {
        perMint = bound(perMint, 1, 1e24);
        uint256 maxMints = bound(uint256(completeMints), 1, 40);
        remainder = bound(remainder, 0, perMint - 1);
        uint256 totalSupply = maxMints * perMint + remainder;

        MemeToken token = _deploy(alice, "FZ", totalSupply, perMint);

        for (uint256 i = 0; i < maxMints; i++) {
            vm.prank(alice);
            factory.mintInscription(address(token));
        }

        assertEq(token.totalSupply(), maxMints * perMint);
        assertLe(token.totalSupply(), totalSupply);

        vm.prank(bob);
        vm.expectRevert(MemeToken.CapExceeded.selector);
        factory.mintInscription(address(token));

        assertEq(token.totalSupply(), maxMints * perMint);
    }

    function testFuzz_DeployRejectsInvalidParams(string memory symbol, uint256 totalSupply, uint256 perMint) public {
        vm.assume(bytes(symbol).length > 0);
        vm.assume(totalSupply == 0 || perMint == 0 || perMint > totalSupply);

        vm.expectRevert(MemeFactory.InvalidSupply.selector);
        factory.deployInscription(symbol, totalSupply, perMint);
    }
}
