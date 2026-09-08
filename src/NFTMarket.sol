// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @notice NFTMarket: 用 MyTokenERC1363（ERC-20）购买 MyERC721NFT
/// @dev 上架时将 NFT 托管到本合约；购买时用 TOKEN 支付给卖家并领取 NFT
contract NFTMarket is IERC721Receiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice 支付代币（如 MyTokenERC1363）
    IERC20 public immutable paymentToken;
    /// @notice 交易的 NFT（如 MyERC721NFT）
    IERC721 public immutable nft;

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

    constructor(IERC20 paymentToken_, IERC721 nft_) {
        if (address(paymentToken_) == address(0) || address(nft_) == address(0)) revert ZeroAddress();
        paymentToken = paymentToken_;
        nft = nft_;
    }

    /// @notice NFT 持有者上架：设置用多少 TOKEN 购买该 NFT，并将 NFT 转入市场托管
    /// @param tokenId 要上架的 NFT tokenId
    /// @param price 标价（TOKEN 数量，含 decimals）
    function list(uint256 tokenId, uint256 price) external nonReentrant {
        if (price == 0) revert ZeroPrice();
        if (listings[tokenId].price != 0) revert AlreadyListed();
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();

        listings[tokenId] = Listing({seller: msg.sender, price: price});

        // 需事先 approve(market, tokenId) 或 setApprovalForAll
        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit Listed(tokenId, msg.sender, price);
    }

    /// @notice 购买已上架的 NFT：转入不少于标价的 TOKEN，领取对应 NFT
    /// @param tokenId 要购买的 NFT tokenId
    /// @param amount 买家支付的 TOKEN 数量（须 >= 标价；按标价结算给卖家）
    function buyNFT(uint256 tokenId, uint256 amount) external nonReentrant {
        Listing memory listing = listings[tokenId];
        if (listing.price == 0) revert NotListed();
        if (amount < listing.price) revert InsufficientPayment(listing.price, amount);

        // CEI: 先清状态再交互
        delete listings[tokenId];

        paymentToken.safeTransferFrom(msg.sender, listing.seller, listing.price);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Bought(tokenId, msg.sender, listing.seller, listing.price);
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
