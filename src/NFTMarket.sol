// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1363Receiver} from "openzeppelin-contracts/contracts/interfaces/IERC1363Receiver.sol";
import {IERC1363Spender} from "openzeppelin-contracts/contracts/interfaces/IERC1363Spender.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @notice NFTMarket: 用 MyTokenERC1363 购买 MyERC721NFT
/// @dev 上架路径:
/// 1. approve + list()
/// 2. safeTransferFrom(seller, market, tokenId, abi.encode(price)) -> onERC721Received
/// @dev 购买路径:
/// 1. ERC20: approve + buyNFT()
/// 2. transferAndCall / transferFromAndCall -> onTransferReceived（data = abi.encode(tokenId)）
/// 3. approveAndCall -> onApprovalReceived（data = abi.encode(tokenId)，内部 transferFrom 付给卖家）
contract NFTMarket is IERC721Receiver, IERC1363Receiver, IERC1363Spender, ERC165, ReentrancyGuard {
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
    error InvalidToken();
    error InvalidData();

    constructor(IERC20 paymentToken_, IERC721 nft_) {
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
        _buyWithPull(msg.sender, tokenId, amount);
    }

    /// @inheritdoc IERC1363Receiver
    /// @dev TOKEN 已转入本合约；data 须为 abi.encode(tokenId)。超额部分退回买家。
    function onTransferReceived(address, address from, uint256 value, bytes calldata data)
        external
        override
        nonReentrant
        returns (bytes4)
    {
        // 仅允许绑定的支付代币回调，防止伪造 TOKEN 触发购买
        if (msg.sender != address(paymentToken)) revert InvalidToken();
        if (from == address(0)) revert ZeroAddress();

        uint256 tokenId = _decodeTokenId(data);
        Listing memory listing = _consumeListing(tokenId, value);

        // TOKEN 已在本合约：按标价付给卖家，超额退回买家
        paymentToken.safeTransfer(listing.seller, listing.price);
        uint256 refund = value - listing.price;
        if (refund > 0) {
            paymentToken.safeTransfer(from, refund);
        }

        // 交割 NFT 给付款人 from（transferFromAndCall 时也是 token 来源地址）
        nft.safeTransferFrom(address(this), from, tokenId);
        emit Bought(tokenId, from, listing.seller, listing.price);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    /// @inheritdoc IERC1363Spender
    /// @dev data 须为 abi.encode(tokenId)；按标价 transferFrom 付给卖家（不超额拉款）
    function onApprovalReceived(address owner, uint256 value, bytes calldata data)
        external
        override
        nonReentrant
        returns (bytes4)
    {
        if (msg.sender != address(paymentToken)) revert InvalidToken();
        if (owner == address(0)) revert ZeroAddress();

        uint256 tokenId = _decodeTokenId(data);
        // approveAndCall：按标价从 owner 拉 TOKEN 给卖家并交割 NFT
        _buyWithPull(owner, tokenId, value);

        return IERC1363Spender.onApprovalReceived.selector;
    }

    /// @inheritdoc IERC721Receiver
    /// @dev 两种来源：
    /// 1) list() 已写入挂单后再 pull（data 可为空）
    /// 2) 卖家直接 safeTransferFrom(..., data=abi.encode(price))，无需 approve
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (msg.sender != address(nft)) revert InvalidToken();

        Listing memory existing = listings[tokenId];
        if (existing.price != 0) {
            // list() 路径：挂单已存在，仅确认卖家一致
            if (existing.seller != from) revert NotOwner();
            return IERC721Receiver.onERC721Received.selector;
        }

        // 直接转入路径：data 必须为 abi.encode(price)
        if (from == address(0)) revert ZeroAddress();
        if (data.length != 32) revert InvalidData();
        uint256 price = abi.decode(data, (uint256));
        if (price == 0) revert ZeroPrice();

        listings[tokenId] = Listing({seller: from, price: price});
        emit Listed(tokenId, from, price);

        return IERC721Receiver.onERC721Received.selector;
    }

    /// @dev approve + buyNFT / approveAndCall：从买家拉标价 TOKEN 给卖家并交割 NFT
    function _buyWithPull(address buyer, uint256 tokenId, uint256 amount) private {
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
}
