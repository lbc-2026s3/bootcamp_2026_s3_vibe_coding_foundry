// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {AdvancedMultiToken} from "../../src/nft/AdvancedMultiToken.sol";

contract MultiTokenReceiver is IERC1155Receiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

/// @dev 铸造回调里再铸造一次。外层 mint 已占用重入锁，内层应失败且不影响已记账的数量。
contract ReenteringMinter is IERC1155Receiver {
    AdvancedMultiToken internal token;
    uint256 internal tokenId;
    bytes public revertData;
    bool public tried;

    function setToken(AdvancedMultiToken token_, uint256 tokenId_) external {
        token = token_;
        tokenId = tokenId_;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        tried = true;
        try token.mint(address(this), tokenId, 1, "") {}
        catch (bytes memory reason) {
            revertData = reason;
        }
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

contract AdvancedMultiTokenTest is Test, IERC1155Errors {
    AdvancedMultiToken internal token;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    event TokenCreated(uint256 indexed id, string name, string symbol, bool isFungible);
    event TokenMinted(uint256 indexed id, address indexed to, uint256 amount);
    event TokenBurned(uint256 indexed id, address indexed from, uint256 amount);
    event URI(string value, uint256 indexed id);

    function setUp() public {
        token = new AdvancedMultiToken();
    }

    function test_CreateToken_StoresMetadataAndUri() public {
        vm.expectEmit(true, false, false, true, address(token));
        emit TokenCreated(1, "Gold", "GOLD", true);
        vm.expectEmit(true, false, false, true, address(token));
        emit URI("ipfs://gold", 1);

        token.createToken(1, "Gold", "GOLD", 100, true, "ipfs://gold");

        (
            string memory name_,
            string memory symbol_,
            uint256 maxSupply,
            uint256 currentSupply,
            bool isFungible,
            bool isPaused
        ) = token.tokenInfo(1);
        assertEq(name_, "Gold");
        assertEq(symbol_, "GOLD");
        assertEq(maxSupply, 100);
        assertEq(currentSupply, 0);
        assertTrue(isFungible);
        assertFalse(isPaused);
        assertEq(token.uri(1), "ipfs://gold");
        assertEq(token.owner(), address(this));
        assertFalse(token.paused());
    }

    function test_CreateToken_AllowsIdZeroWhenSupplyIsPositive() public {
        token.createToken(0, "Unique", "UNQ", 1, false, "ipfs://0");
        assertEq(token.uri(0), "ipfs://0");
        (,, uint256 maxSupply,, bool isFungible,) = token.tokenInfo(0);
        assertEq(maxSupply, 1);
        assertFalse(isFungible);
    }

    function test_RevertWhen_TokenAlreadyExists() public {
        token.createToken(1, "Gold", "GOLD", 100, true, "ipfs://gold");
        vm.expectRevert(bytes("Token already exists"));
        token.createToken(1, "Silver", "SLV", 50, true, "ipfs://silver");
        assertEq(token.uri(1), "ipfs://gold");
    }

    function test_RevertWhen_MaxSupplyIsZero() public {
        vm.expectRevert(bytes("Max supply is zero"));
        token.createToken(1, "Gold", "GOLD", 0, true, "ipfs://gold");
        assertEq(token.uri(1), "");
    }

    /// @notice 模糊测试。带参数的 test 函数不会手工传参，Forge 每次填一个随机地址再跑一遍。
    /// @param caller 随机调用者。address(this) 是部署者兼 owner，必须排除，否则 createToken 会成功。
    function test_RevertWhen_NonOwnerCreates(address caller) public {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        token.createToken(1, "Gold", "GOLD", 100, true, "ipfs://gold");
    }

    function test_Mint_ByOwnerUpdatesSupplyAndBalance() public {
        token.createToken(1, "Gold", "GOLD", 100, true, "ipfs://gold");

        vm.expectEmit(true, true, false, true, address(token));
        emit TokenMinted(1, alice, 40);

        token.mint(alice, 1, 40, "");

        assertEq(token.balanceOf(alice, 1), 40);
        assertEq(_currentSupply(1), 40);
    }

    function test_Mint_ByGrantedMinter() public {
        token.createToken(1, "Gold", "GOLD", 100, true, "ipfs://gold");
        token.setMinter(bob, true);

        vm.prank(bob);
        token.mint(alice, 1, 5, "data");

        assertEq(token.balanceOf(alice, 1), 5);
        assertTrue(token.minters(bob));
    }

    function test_SetMinter_CanRevoke() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        token.setMinter(bob, true);
        token.setMinter(bob, false);

        vm.prank(bob);
        vm.expectRevert(bytes("Not a minter"));
        token.mint(alice, 1, 1, "");
        assertEq(_currentSupply(1), 0);
    }

    function test_RevertWhen_NonMinterMints() public {
        token.createToken(1, "Gold", "GOLD", 100, true, "ipfs://gold");
        vm.prank(alice);
        vm.expectRevert(bytes("Not a minter"));
        token.mint(alice, 1, 1, "");
    }

    function test_RevertWhen_MintUnknownToken() public {
        vm.expectRevert(bytes("Token does not exist"));
        token.mint(alice, 1, 1, "");
    }

    function test_RevertWhen_MintExceedsMaxSupply() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        token.mint(alice, 1, 8, "");

        vm.expectRevert(bytes("Exceeds max supply"));
        token.mint(alice, 1, 3, "");
        assertEq(token.balanceOf(alice, 1), 8);
        assertEq(_currentSupply(1), 8);
    }

    function testFuzz_Mint_UpToMaxSupply(uint256 amount) public {
        uint256 maxSupply = 1000;
        amount = bound(amount, 0, maxSupply);
        token.createToken(1, "Gold", "GOLD", maxSupply, true, "ipfs://gold");

        token.mint(alice, 1, amount, "");

        assertEq(token.balanceOf(alice, 1), amount);
        assertEq(_currentSupply(1), amount);
    }

    function testFuzz_RevertWhen_MintExceedsMaxSupply(uint256 amount) public {
        token.createToken(1, "Gold", "GOLD", 100, true, "ipfs://gold");
        amount = bound(amount, 101, type(uint256).max);

        vm.expectRevert(bytes("Exceeds max supply"));
        token.mint(alice, 1, amount, "");
        assertEq(_currentSupply(1), 0);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidReceiver.selector, address(0)));
        token.mint(address(0), 1, 1, "");
        assertEq(_currentSupply(1), 0);
    }

    function test_Mint_ToContractReceiver() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        MultiTokenReceiver receiver = new MultiTokenReceiver();

        token.mint(address(receiver), 1, 2, "");

        assertEq(token.balanceOf(address(receiver), 1), 2);
    }

    function test_RevertWhen_MintToContractWithoutReceiver() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidReceiver.selector, address(this)));
        token.mint(address(this), 1, 1, "");
        assertEq(_currentSupply(1), 0);
    }

    function test_Mint_ReentrancyDoesNotDoubleSupply() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        ReenteringMinter receiver = new ReenteringMinter();
        receiver.setToken(token, 1);
        token.setMinter(address(receiver), true);

        token.mint(address(receiver), 1, 4, "");

        assertTrue(receiver.tried());
        assertEq(receiver.revertData(), abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector));
        assertEq(token.balanceOf(address(receiver), 1), 4);
        assertEq(_currentSupply(1), 4);

        token.mint(alice, 1, 1, "");
        assertEq(_currentSupply(1), 5);
    }

    function test_MintBatch_MintsSeveralIds() public {
        token.createToken(1, "Gold", "GOLD", 100, true, "ipfs://gold");
        token.createToken(2, "Gem", "GEM", 5, false, "ipfs://gem");

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 25;
        amounts[1] = 1;

        token.mintBatch(alice, ids, amounts, "");

        assertEq(token.balanceOf(alice, 1), 25);
        assertEq(token.balanceOf(alice, 2), 1);
        assertEq(_currentSupply(1), 25);
        assertEq(_currentSupply(2), 1);
    }

    function test_MintBatch_SameIdCountsTowardSupply() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;
        amounts[0] = 6;
        amounts[1] = 4;

        token.mintBatch(alice, ids, amounts, "");

        assertEq(token.balanceOf(alice, 1), 10);
        assertEq(_currentSupply(1), 10);
    }

    function test_RevertWhen_MintBatchSameIdExceedsSupply() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;
        amounts[0] = 6;
        amounts[1] = 6;

        vm.expectRevert(bytes("Exceeds max supply"));
        token.mintBatch(alice, ids, amounts, "");
        assertEq(token.balanceOf(alice, 1), 0);
        assertEq(_currentSupply(1), 0);
    }

    function test_RevertWhen_MintBatchLengthMismatch() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        amounts[0] = 1;
        amounts[1] = 1;

        vm.expectRevert(bytes("Arrays length mismatch"));
        token.mintBatch(alice, ids, amounts, "");
    }

    function test_RevertWhen_MintBatchRollsBackEarlierId() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        token.createToken(2, "Gem", "GEM", 1, false, "ipfs://gem");
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 4;
        amounts[1] = 2;

        vm.expectRevert(bytes("Exceeds max supply"));
        token.mintBatch(alice, ids, amounts, "");
        assertEq(_currentSupply(1), 0);
        assertEq(_currentSupply(2), 0);
    }

    function test_Burn_ByHolderFreesSupply() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        token.mint(alice, 1, 10, "");

        vm.expectEmit(true, true, false, true, address(token));
        emit TokenBurned(1, alice, 4);
        vm.prank(alice);
        token.burn(alice, 1, 4);

        assertEq(token.balanceOf(alice, 1), 6);
        assertEq(_currentSupply(1), 6);

        token.mint(bob, 1, 4, "");
        assertEq(_currentSupply(1), 10);
    }

    function test_Burn_ByApprovedOperator() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        token.mint(alice, 1, 3, "");
        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        token.burn(alice, 1, 3);

        assertEq(token.balanceOf(alice, 1), 0);
        assertEq(_currentSupply(1), 0);
    }

    function test_RevertWhen_BurnUnauthorized() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        token.mint(alice, 1, 3, "");

        vm.prank(bob);
        vm.expectRevert(bytes("Not authorized"));
        token.burn(alice, 1, 1);
        assertEq(_currentSupply(1), 3);
    }

    function test_RevertWhen_BurnExceedsBalance() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        token.mint(alice, 1, 1, "");

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155InsufficientBalance.selector, alice, 1, 2, 1));
        token.burn(alice, 1, 2);
        assertEq(_currentSupply(1), 1);
    }

    function test_RevertWhen_BurnUnknownToken() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Token does not exist"));
        token.burn(alice, 1, 1);
    }

    function testFuzz_Burn_Partial(uint256 minted, uint256 burned) public {
        minted = bound(minted, 1, 500);
        burned = bound(burned, 1, minted);
        token.createToken(1, "Gold", "GOLD", 500, true, "ipfs://gold");
        token.mint(alice, 1, minted, "");

        vm.prank(alice);
        token.burn(alice, 1, burned);

        assertEq(token.balanceOf(alice, 1), minted - burned);
        assertEq(_currentSupply(1), minted - burned);
    }

    function test_BurnBatch_BurnsAndRejectsMismatch() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        token.createToken(2, "Gem", "GEM", 5, false, "ipfs://gem");
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 4;
        amounts[1] = 1;
        token.mintBatch(alice, ids, amounts, "");

        amounts[0] = 3;
        vm.prank(alice);
        token.burnBatch(alice, ids, amounts);
        assertEq(token.balanceOf(alice, 1), 1);
        assertEq(token.balanceOf(alice, 2), 0);
        assertEq(_currentSupply(1), 1);
        assertEq(_currentSupply(2), 0);

        uint256[] memory shortIds = new uint256[](1);
        shortIds[0] = 1;
        vm.prank(alice);
        vm.expectRevert(bytes("Arrays length mismatch"));
        token.burnBatch(alice, shortIds, amounts);
        assertEq(_currentSupply(1), 1);
    }

    function test_SetURI_UpdatesExistingToken() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");

        vm.expectEmit(true, false, false, true, address(token));
        emit URI("ipfs://gold-v2", 1);
        token.setURI(1, "ipfs://gold-v2");

        assertEq(token.uri(1), "ipfs://gold-v2");
    }

    function test_RevertWhen_SetURIUnknownOrNonOwner() public {
        vm.expectRevert(bytes("Token does not exist"));
        token.setURI(1, "ipfs://gold");

        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.setURI(1, "ipfs://other");
        assertEq(token.uri(1), "ipfs://gold");
    }

    function test_PauseToken_BlocksMintButNotTransfer() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        token.mint(alice, 1, 2, "");
        token.pauseToken(1);

        vm.expectRevert(bytes("Token minting paused"));
        token.mint(bob, 1, 1, "");

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 1, 1, "");
        assertEq(token.balanceOf(bob, 1), 1);
        assertEq(_currentSupply(1), 2);

        token.unpauseToken(1);
        token.mint(bob, 1, 1, "");
        assertEq(_currentSupply(1), 3);
    }

    function test_RevertWhen_PauseUnknownToken() public {
        vm.expectRevert(bytes("Token does not exist"));
        token.pauseToken(1);
        vm.expectRevert(bytes("Token does not exist"));
        token.unpauseToken(1);
    }

    function test_Pause_BlocksMintBurnAndTransfer() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        token.mint(alice, 1, 2, "");
        token.pause();
        assertTrue(token.paused());

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        token.mint(alice, 1, 1, "");

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        token.burn(alice, 1, 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        token.safeTransferFrom(alice, bob, 1, 1, "");

        assertEq(token.balanceOf(alice, 1), 2);
        assertEq(_currentSupply(1), 2);

        token.unpause();
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 1, 1, "");
        assertEq(token.balanceOf(bob, 1), 1);
        assertFalse(token.paused());
    }

    function test_RevertWhen_NonOwnerPauses() public {
        token.createToken(1, "Gold", "GOLD", 10, true, "ipfs://gold");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.pause();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.pauseToken(1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.setMinter(alice, true);
        assertFalse(token.minters(alice));
    }

    function _currentSupply(uint256 id) private view returns (uint256 currentSupply) {
        (,,, currentSupply,,) = token.tokenInfo(id);
    }
}
