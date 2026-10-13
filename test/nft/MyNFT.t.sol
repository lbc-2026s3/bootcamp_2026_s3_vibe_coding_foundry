// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MyNFT} from "../../src/nft/MyNFT.sol";

contract NFTReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @dev 收到 NFT 后再调 mint，用来确认铸造回调不能继续占供应量。
contract ReenteringMinter is IERC721Receiver {
    MyNFT public immutable nft;

    constructor(MyNFT nft_) {
        nft = nft_;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        nft.mint{value: nft.MINT_PRICE()}(address(this));
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @dev receive 里再次调用 withdraw。外层 call 已把余额转走，用来确认重入会被拦住而不是再次成功。
contract ReenteringOwner {
    MyNFT public immutable nft;
    uint256 public attempts;

    constructor(MyNFT nft_) {
        nft = nft_;
    }

    function attack() external {
        nft.withdraw();
    }

    receive() external payable {
        attempts += 1;
        if (attempts == 1) {
            nft.withdraw();
        }
    }
}

contract MyNFTTest is Test, IERC721Errors {
    MyNFT internal nft;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    event TokenMinted(address indexed to, uint256 indexed tokenId);
    event BaseURIUpdated(string newBaseURI);
    event TokenURIUpdated(uint256 indexed tokenId, string tokenURI);

    /// @dev ERC721(name, symbol) 占 0-5，Ownable._owner 占 6，ReentrancyGuard 用 ERC-7201 槽。
    uint256 internal constant NEXT_TOKEN_ID_SLOT = 7;

    function setUp() public {
        nft = new MyNFT("MyNFT", "MNFT");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function test_Mint_AssignsSequentialIdsAndKeepsPayment() public {
        vm.expectEmit(true, true, false, true, address(nft));
        emit TokenMinted(bob, 0);

        vm.prank(alice);
        uint256 tokenId = nft.mint{value: nft.MINT_PRICE()}(bob);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), bob);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.totalSupply(), 1);
        assertEq(address(nft).balance, nft.MINT_PRICE());
        assertEq(nft.tokenURI(tokenId), "0");
    }

    function test_Mint_KeepsOverpayment() public {
        vm.prank(alice);
        nft.mint{value: 1 ether}(alice);

        assertEq(address(nft).balance, 1 ether);
    }

    function test_RevertWhen_MintUnderpaid() public {
        uint256 price = nft.MINT_PRICE();
        vm.prank(alice);
        vm.expectRevert(bytes("Insufficient payment"));
        nft.mint{value: price - 1}(alice);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        uint256 price = nft.MINT_PRICE();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidReceiver.selector, address(0)));
        nft.mint{value: price}(address(0));
    }

    function test_Mint_ToContractReceiver() public {
        NFTReceiver receiver = new NFTReceiver();

        vm.prank(alice);
        uint256 tokenId = nft.mint{value: nft.MINT_PRICE()}(address(receiver));

        assertEq(nft.ownerOf(tokenId), address(receiver));
    }

    function test_RevertWhen_ReceiverReentersMint() public {
        ReenteringMinter receiver = new ReenteringMinter(nft);
        uint256 price = nft.MINT_PRICE();
        vm.deal(address(receiver), price);
        _setNextTokenId(nft.MAX_SUPPLY() - 2);

        vm.prank(alice);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        nft.mintBatch{value: price * 2}(address(receiver), 2);

        assertEq(nft.totalSupply(), nft.MAX_SUPPLY() - 2);
    }

    function test_RevertWhen_MintToContractWithoutReceiver() public {
        uint256 price = nft.MINT_PRICE();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidReceiver.selector, address(this)));
        nft.mint{value: price}(address(this));
    }

    function test_MintBatch_MintsQuantityAndChargesSum() public {
        vm.prank(alice);
        uint256[] memory ids = nft.mintBatch{value: nft.MINT_PRICE() * 3}(bob, 3);

        assertEq(ids.length, 3);
        assertEq(ids[0], 0);
        assertEq(ids[2], 2);
        assertEq(nft.balanceOf(bob), 3);
        assertEq(nft.totalSupply(), 3);
        assertEq(address(nft).balance, nft.MINT_PRICE() * 3);
    }

    /// @notice 模糊测试。带参数的 test 函数不会手工传参，Forge 每次填一个随机数再跑一遍。
    /// @param quantity 批量数量。bound 把它收进 11 到 1000；合约只允许 1 到 10。0 由另一个测试覆盖。
    function test_RevertWhen_MintBatchQuantityOutOfRange(uint256 quantity) public {
        quantity = bound(quantity, 11, 1000);
        vm.prank(alice);
        vm.expectRevert(bytes("Invalid quantity"));
        nft.mintBatch{value: 100 ether}(alice, quantity);
    }

    function test_RevertWhen_MintBatchZeroQuantity() public {
        uint256 price = nft.MINT_PRICE();
        vm.prank(alice);
        vm.expectRevert(bytes("Invalid quantity"));
        nft.mintBatch{value: price}(alice, 0);
    }

    function test_RevertWhen_MintBatchUnderpaid() public {
        uint256 price = nft.MINT_PRICE();
        vm.prank(alice);
        vm.expectRevert(bytes("Insufficient payment"));
        nft.mintBatch{value: price * 2 - 1}(alice, 2);
    }

    function test_RevertWhen_SupplyExhausted() public {
        uint256 price = nft.MINT_PRICE();
        _setNextTokenId(nft.MAX_SUPPLY());

        vm.prank(alice);
        vm.expectRevert(bytes("Max supply reached"));
        nft.mint{value: price}(alice);
    }

    function test_LastTokenCanBeMinted() public {
        _setNextTokenId(nft.MAX_SUPPLY() - 1);

        vm.prank(alice);
        uint256 tokenId = nft.mint{value: nft.MINT_PRICE()}(alice);

        assertEq(tokenId, nft.MAX_SUPPLY() - 1);
        assertEq(nft.totalSupply(), nft.MAX_SUPPLY());
    }

    function test_RevertWhen_MintBatchExceedsSupply() public {
        uint256 price = nft.MINT_PRICE();
        _setNextTokenId(nft.MAX_SUPPLY() - 2);

        vm.prank(alice);
        vm.expectRevert(bytes("Exceeds max supply"));
        nft.mintBatch{value: price * 3}(alice, 3);
    }

    function test_MintBatch_FitsRemainingSupply() public {
        _setNextTokenId(nft.MAX_SUPPLY() - 2);

        vm.prank(alice);
        uint256[] memory ids = nft.mintBatch{value: nft.MINT_PRICE() * 2}(alice, 2);

        assertEq(ids[0], nft.MAX_SUPPLY() - 2);
        assertEq(ids[1], nft.MAX_SUPPLY() - 1);
        assertEq(nft.totalSupply(), nft.MAX_SUPPLY());
    }

    function test_TokenURI_UsesSpecificUriOverBase() public {
        vm.prank(alice);
        uint256 tokenId = nft.mint{value: nft.MINT_PRICE()}(alice);

        vm.expectEmit(false, false, false, true, address(nft));
        emit BaseURIUpdated("ipfs://base/");
        nft.setBaseURI("ipfs://base/");
        assertEq(nft.tokenURI(tokenId), "ipfs://base/0");

        vm.expectEmit(true, false, false, true, address(nft));
        emit TokenURIUpdated(tokenId, "ipfs://custom");
        nft.setTokenURI(tokenId, "ipfs://custom");
        assertEq(nft.tokenURI(tokenId), "ipfs://custom");
    }

    function test_RevertWhen_TokenURIForUnminted() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, 0));
        nft.tokenURI(0);
    }

    function test_RevertWhen_SetTokenURIForUnminted() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, 0));
        nft.setTokenURI(0, "ipfs://missing");
    }

    function test_RevertWhen_NonOwnerSetsMetadata() public {
        vm.prank(alice);
        nft.mint{value: nft.MINT_PRICE()}(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.setBaseURI("ipfs://nope/");

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.setTokenURI(0, "ipfs://nope");
    }

    function test_Withdraw_SendsBalanceToOwner() public {
        vm.prank(alice);
        nft.mint{value: 1 ether}(alice);

        uint256 ownerBefore = address(this).balance;
        nft.withdraw();

        assertEq(address(nft).balance, 0);
        assertEq(address(this).balance, ownerBefore + 1 ether);
    }

    function test_RevertWhen_WithdrawEmpty() public {
        vm.expectRevert(bytes("No balance to withdraw"));
        nft.withdraw();
    }

    function test_RevertWhen_NonOwnerWithdraws() public {
        vm.prank(alice);
        nft.mint{value: nft.MINT_PRICE()}(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.withdraw();
    }

    function test_RevertWhen_WithdrawReenters() public {
        ReenteringOwner attacker = new ReenteringOwner(nft);
        nft.transferOwnership(address(attacker));

        vm.prank(alice);
        nft.mint{value: nft.MINT_PRICE()}(alice);

        // 低级 call 会吞掉内层 ReentrancyGuardReentrantCall，外层只看到转账失败。
        vm.expectRevert(bytes("Withdrawal failed"));
        attacker.attack();
        assertEq(address(nft).balance, nft.MINT_PRICE());
    }

    function testFuzz_MintBatch_ConservesEth(uint256 quantity, uint256 extra) public {
        quantity = bound(quantity, 1, 10);
        extra = bound(extra, 0, 5 ether);
        uint256 value = nft.MINT_PRICE() * quantity + extra;

        vm.prank(alice);
        nft.mintBatch{value: value}(alice, quantity);

        assertEq(nft.balanceOf(alice), quantity);
        assertEq(nft.totalSupply(), quantity);
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(quantity - 1), alice);
        assertEq(address(nft).balance, value);
    }

    function _setNextTokenId(uint256 nextId) internal {
        vm.store(address(nft), bytes32(NEXT_TOKEN_ID_SLOT), bytes32(nextId));
        assertEq(nft.totalSupply(), nextId);
    }

    receive() external payable {}
}
