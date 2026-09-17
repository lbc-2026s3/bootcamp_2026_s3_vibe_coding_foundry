// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1363Receiver} from "openzeppelin-contracts/contracts/interfaces/IERC1363Receiver.sol";
import {IERC1363Spender} from "openzeppelin-contracts/contracts/interfaces/IERC1363Spender.sol";
import {ERC165Upgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/introspection/ERC165Upgradeable.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @notice NFTMarket 的可升级基类：paymentToken / nft 存于 proxy 存储（非 immutable）
/// @dev 行为与 `NFTMarket` 对齐；子合约通过 `__NFTMarket_init` 初始化
/// @dev OZ v5 ReentrancyGuard 已用 ERC-7201 namespaced storage，可直接用于可升级合约
abstract contract NFTMarketUpgradeable is
    Initializable,
    IERC721Receiver,
    IERC1363Receiver,
    IERC1363Spender,
    ERC165Upgradeable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    /// @notice 支付代币
    IERC20 public paymentToken;
    /// @notice 交易的 NFT
    IERC721 public nft;

    struct Listing {
        address seller;
        uint256 price;
    }

    /// @notice tokenId => 挂单信息；price == 0 表示未上架
    mapping(uint256 => Listing) public listings;

    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);

    error ZeroAddress();
    error ZeroPrice();
    error NotOwner();
    error NotListed();
    error InsufficientPayment(uint256 price, uint256 amount);
    error AlreadyListed();
    error InvalidToken();
    error InvalidData();

    /// @dev 子合约 initializer 内调用；禁止直接暴露为 public initializer
    function __NFTMarket_init(IERC20 paymentToken_, IERC721 nft_) internal onlyInitializing {
        __ERC165_init();
        __NFTMarket_init_unchained(paymentToken_, nft_);
    }

    function __NFTMarket_init_unchained(IERC20 paymentToken_, IERC721 nft_) internal onlyInitializing {
        if (address(paymentToken_) == address(0) || address(nft_) == address(0)) revert ZeroAddress();
        paymentToken = paymentToken_;
        nft = nft_;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC1363Receiver).interfaceId || interfaceId == type(IERC1363Spender).interfaceId
            || interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice NFT 持有者上架：设置用多少 TOKEN 购买该 NFT，并将 NFT 转入市场托管
    function list(uint256 tokenId, uint256 price) external nonReentrant {
        if (price == 0) revert ZeroPrice();
        if (listings[tokenId].price != 0) revert AlreadyListed();
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();

        listings[tokenId] = Listing({seller: msg.sender, price: price});
        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit Listed(tokenId, msg.sender, price);
    }

    /// @notice 购买已上架的 NFT：转入不少于标价的 TOKEN，领取对应 NFT
    function buyNFT(uint256 tokenId, uint256 amount) external nonReentrant {
        _buyWithPull(msg.sender, tokenId, amount);
    }

    /// @inheritdoc IERC1363Receiver
    function onTransferReceived(address, address from, uint256 value, bytes calldata data)
        external
        override
        nonReentrant
        returns (bytes4)
    {
        if (msg.sender != address(paymentToken)) revert InvalidToken();
        if (from == address(0)) revert ZeroAddress();

        uint256 tokenId = _decodeTokenId(data);
        Listing memory listing = _consumeListing(tokenId, value);

        paymentToken.safeTransfer(listing.seller, listing.price);
        uint256 refund = value - listing.price;
        if (refund > 0) {
            paymentToken.safeTransfer(from, refund);
        }

        nft.safeTransferFrom(address(this), from, tokenId);
        emit Bought(tokenId, from, listing.seller, listing.price);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    /// @inheritdoc IERC1363Spender
    function onApprovalReceived(address owner, uint256 value, bytes calldata data)
        external
        override
        nonReentrant
        returns (bytes4)
    {
        if (msg.sender != address(paymentToken)) revert InvalidToken();
        if (owner == address(0)) revert ZeroAddress();

        uint256 tokenId = _decodeTokenId(data);
        _buyWithPull(owner, tokenId, value);

        return IERC1363Spender.onApprovalReceived.selector;
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (msg.sender != address(nft)) revert InvalidToken();

        Listing memory existing = listings[tokenId];
        // 正常上架流程:
        // 1. list()函数，先写入 listings[tokenId] = {seller, price}
        // 2. nft.safeTransferFrom(seller → market)
        // 3. NFT 合约回调 onERC721Received
        if (existing.price != 0) {
            if (existing.seller != from) revert NotOwner();
            return IERC721Receiver.onERC721Received.selector;
        }

        // safeTransferFrom 方式上架 NFT，此时没有 list 信息
        if (from == address(0)) revert ZeroAddress();
        if (data.length != 32) revert InvalidData();
        uint256 price = abi.decode(data, (uint256));
        if (price == 0) revert ZeroPrice();

        listings[tokenId] = Listing({seller: from, price: price});
        emit Listed(tokenId, from, price);

        return IERC721Receiver.onERC721Received.selector;
    }

    /// @dev approve + buyNFT / approveAndCall：从买家拉标价 TOKEN 给卖家并交割 NFT
    function _buyWithPull(address buyer, uint256 tokenId, uint256 amount) internal {
        Listing memory listing = _consumeListing(tokenId, amount);

        paymentToken.safeTransferFrom(buyer, listing.seller, listing.price);
        nft.safeTransferFrom(address(this), buyer, tokenId);

        emit Bought(tokenId, buyer, listing.seller, listing.price);
    }

    function _consumeListing(uint256 tokenId, uint256 amount) private returns (Listing memory listing) {
        listing = listings[tokenId];
        if (listing.price == 0) revert NotListed();
        if (amount < listing.price) revert InsufficientPayment(listing.price, amount);

        delete listings[tokenId];
    }

    function _decodeTokenId(bytes calldata data) private pure returns (uint256 tokenId) {
        if (data.length != 32) revert InvalidData();
        tokenId = abi.decode(data, (uint256));
    }

    uint256[50] private __gap;
}
