// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import {MyTokenERC2612Permit} from "../src/MyTokenERC2612Permit.sol";

contract MyTokenERC2612PermitTest is Test {
    MyTokenERC2612Permit public token;

    address public deployer = makeAddr("deployer");
    uint256 public alicePk = 0xA11CE;
    address public alice = vm.addr(alicePk);
    address public bob = makeAddr("bob");

    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        vm.prank(deployer);
        token = new MyTokenERC2612Permit();
    }

    function test_SupportsInterface_IERC20Permit() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC20Permit).interfaceId));
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function _signPermit(address owner, uint256 ownerPk, address spender, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, token.nonces(owner), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(ownerPk, digest);
    }

    function test_InitialSupplyMintedToDeployer() public view {
        assertEq(token.totalSupply(), token.INITIAL_SUPPLY());
        assertEq(token.balanceOf(deployer), token.INITIAL_SUPPLY());
        assertEq(token.name(), "MyToken2612");
        assertEq(token.symbol(), "MT2612");
        assertEq(token.decimals(), 18);
    }

    function test_Permit_SetsAllowance() public {
        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(deployer);
        token.transfer(alice, amount);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, bob, amount, deadline);

        token.permit(alice, bob, amount, deadline, v, r, s);

        assertEq(token.allowance(alice, bob), amount);
        assertEq(token.nonces(alice), 1);
    }

    function test_Permit_ThenTransferFrom() public {
        uint256 amount = 50e18;
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(deployer);
        token.transfer(alice, amount);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, bob, amount, deadline);
        token.permit(alice, bob, amount, deadline, v, r, s);

        vm.prank(bob);
        token.transferFrom(alice, bob, amount);

        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(alice, bob), 0);
    }

    function test_RevertWhen_Permit_Expired() public {
        uint256 amount = 10e18;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(deployer);
        token.transfer(alice, amount);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, bob, amount, deadline);

        vm.warp(deadline + 1);
        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612ExpiredSignature.selector, deadline));
        token.permit(alice, bob, amount, deadline, v, r, s);
    }

    function test_RevertWhen_Permit_InvalidSigner() public {
        uint256 amount = 10e18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 bobPk = 0xB0B;

        vm.prank(deployer);
        token.transfer(alice, amount);

        // 用 bob 的私钥签 alice 的 permit,应失败
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, bobPk, bob, amount, deadline);

        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612InvalidSigner.selector, vm.addr(bobPk), alice));
        token.permit(alice, bob, amount, deadline, v, r, s);
    }

    function test_RevertWhen_Permit_Replay() public {
        uint256 amount = 10e18;
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(deployer);
        token.transfer(alice, amount);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, bob, amount, deadline);
        token.permit(alice, bob, amount, deadline, v, r, s);

        // nonce 已递增(现为 1),旧签名对应 digest 不同,recover 出的 signer != owner
        bytes32 replayStructHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, alice, bob, amount, token.nonces(alice), deadline));
        bytes32 replayDigest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), replayStructHash));
        address recovered = ecrecover(replayDigest, v, r, s);
        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612InvalidSigner.selector, recovered, alice));
        token.permit(alice, bob, amount, deadline, v, r, s);
    }

    function testFuzz_Permit_SetsAllowance(uint96 amount, uint64 deadlineOffset) public {
        amount = uint96(bound(amount, 1, 1_000_000e18));
        deadlineOffset = uint64(bound(deadlineOffset, 1, 365 days));
        uint256 deadline = block.timestamp + deadlineOffset;

        vm.prank(deployer);
        token.transfer(alice, amount);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alice, alicePk, bob, amount, deadline);
        token.permit(alice, bob, amount, deadline, v, r, s);

        assertEq(token.allowance(alice, bob), amount);
        assertEq(token.nonces(alice), 1);

        vm.prank(bob);
        token.transferFrom(alice, bob, amount);
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(alice, bob), 0);
    }
}
