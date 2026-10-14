// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title ArtNFT
/// @notice 可标价出售的 ERC721。版税按标价的基点计提，创作者自己来提取，不在成交时再推一笔。
/// @dev 一级市场卖家就是创作者，成交款全部付给卖家。二级市场才从标价里划出版税。
///      转让（包括本合约的成交）会把 `forSale` 清掉，避免旧挂单绑到新持有人身上。
contract ArtNFT is ERC721URIStorage, ERC2981, Ownable, ReentrancyGuard {
    /// @notice 一件作品的标价和版税。`artist` 只是展示名，收款和版税都看地址。
    struct Artwork {
        /// @notice 作品标题。
        string title;
        /// @notice 艺术家展示名，不参与转账。
        string artist;
        /// @notice 当前标价，单位 wei。成交按这个数收款，不按买家多付的 `msg.value`。
        uint256 price;
        /// @notice 是否在售。任何转让（包括本合约成交）都会清成 false。
        bool forSale;
        /// @notice 版税基点，分母是 `ROYALTY_DENOMINATOR`。500 = 5%，上限 `MAX_ROYALTY`。
        uint256 royaltyPercentage;
        /// @notice 铸造者地址。二级市场的版税记在这个地址上，一级市场不另扣。
        address creator;
    }

    /// @notice 版税上限，1000 / 10000 = 10%。
    uint256 public constant MAX_ROYALTY = 1000;
    /// @notice 版税分母。与 ERC-2981 一致，10000 表示基点。
    uint256 public constant ROYALTY_DENOMINATOR = 10_000;

    /// @notice tokenId => 作品信息。
    mapping(uint256 tokenId => Artwork) public artworks;
    /// @notice 创作者地址 => 其铸造过的 tokenId，转手后仍留在这里。
    mapping(address artist => uint256[]) private _artistArtworks;
    /// @notice 创作者地址 => 已计提、尚未提取的版税（wei）。
    mapping(address artist => uint256) public artistRoyalties;

    /// @notice 已铸造数量，也是下一枚 tokenId。
    uint256 public totalArtworks;

    event ArtworkCreated(uint256 indexed tokenId, string title, string artist, uint256 price);
    event ArtworkSold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event RoyaltyAccrued(uint256 indexed tokenId, address indexed artist, uint256 amount);
    event RoyaltyPaid(address indexed artist, uint256 amount);
    event PriceUpdated(uint256 indexed tokenId, uint256 newPrice);
    event SaleToggled(uint256 indexed tokenId, bool forSale);

    error EmptyMetadata();
    error InvalidPrice();
    error RoyaltyTooHigh(uint256 royalty, uint256 maxRoyalty);
    error NotForSale(uint256 tokenId);
    error CannotBuyOwnArtwork(uint256 tokenId);
    error InsufficientPayment(uint256 sent, uint256 price);
    error NotTokenOwner(address caller, uint256 tokenId);
    error NoRoyalties();
    error PaymentFailed(address to);

    constructor() ERC721("Digital Art", "ART") Ownable(msg.sender) {}

    /// @notice 铸造作品并立刻按 `price` 上架。tokenId 由合约递增分配。
    function createArtwork(
        string calldata title,
        string calldata artist,
        uint256 price,
        uint256 royaltyPercentage,
        string calldata tokenURI_
    ) external nonReentrant returns (uint256 tokenId) {
        if (bytes(title).length == 0 || bytes(artist).length == 0 || bytes(tokenURI_).length == 0) {
            revert EmptyMetadata();
        }
        if (price == 0) revert InvalidPrice();
        if (royaltyPercentage > MAX_ROYALTY) revert RoyaltyTooHigh(royaltyPercentage, MAX_ROYALTY);

        tokenId = totalArtworks;
        unchecked {
            totalArtworks = tokenId + 1;
        }

        // 先写挂单，再安全铸造。接收方若在回调里把 token 转走，_update 会清掉 forSale，
        // 不能在回调之后再把新持有人的作品标成在售。
        _setTokenURI(tokenId, tokenURI_);
        _setTokenRoyalty(tokenId, msg.sender, uint96(royaltyPercentage));
        artworks[tokenId] = Artwork({
            title: title,
            artist: artist,
            price: price,
            forSale: true,
            royaltyPercentage: royaltyPercentage,
            creator: msg.sender
        });
        _artistArtworks[msg.sender].push(tokenId);

        emit ArtworkCreated(tokenId, title, artist, price);
        _safeMint(msg.sender, tokenId);
    }

    /// @notice 按标价购买。多付的 ETH 退回。二级市场的版税留在合约里，等创作者提取。
    function buyArtwork(uint256 tokenId) external payable nonReentrant {
        Artwork storage artwork = artworks[tokenId];
        if (!artwork.forSale) revert NotForSale(tokenId);

        address seller = ownerOf(tokenId);
        if (msg.sender == seller) revert CannotBuyOwnArtwork(tokenId);

        uint256 price = artwork.price;
        if (msg.value < price) revert InsufficientPayment(msg.value, price);

        address creator = artwork.creator;
        uint256 royaltyAmount;
        // 一级市场卖家就是创作者，整笔标价付给卖家。二级市场才按基点计提版税。
        if (seller != creator && artwork.royaltyPercentage > 0) {
            royaltyAmount = Math.mulDiv(price, artwork.royaltyPercentage, ROYALTY_DENOMINATOR);
        }
        uint256 sellerAmount = price - royaltyAmount;

        if (royaltyAmount > 0) {
            artistRoyalties[creator] += royaltyAmount;
            emit RoyaltyAccrued(tokenId, creator, royaltyAmount);
        }

        _safeTransfer(seller, msg.sender, tokenId);

        // 版税留在合约里，不在这里转给创作者。多付的部分退回买家。
        _pay(seller, sellerAmount);
        _pay(msg.sender, msg.value - price);

        emit ArtworkSold(tokenId, msg.sender, price);
    }

    /// @notice 持有人改标价。不改变是否在售。
    function setPrice(uint256 tokenId, uint256 newPrice) external {
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(msg.sender, tokenId);
        if (newPrice == 0) revert InvalidPrice();

        artworks[tokenId].price = newPrice;
        emit PriceUpdated(tokenId, newPrice);
    }

    /// @notice 持有人上架或下架。
    function toggleForSale(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(msg.sender, tokenId);

        bool forSale = !artworks[tokenId].forSale;
        artworks[tokenId].forSale = forSale;
        emit SaleToggled(tokenId, forSale);
    }

    /// @notice 创作者提取已计提、尚未转出的版税。
    function withdrawRoyalties() external nonReentrant {
        uint256 amount = artistRoyalties[msg.sender];
        if (amount == 0) revert NoRoyalties();

        artistRoyalties[msg.sender] = 0;
        _pay(msg.sender, amount);
        emit RoyaltyPaid(msg.sender, amount);
    }

    /// @notice 返回该地址铸造过的 tokenId，不是当前持有列表。
    function getArtistArtworks(address artist) external view returns (uint256[] memory) {
        return _artistArtworks[artist];
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @dev 成交和普通转让都会走到这里，挂单只对当前持有人有效。
    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = super._update(to, tokenId, auth);
        if (from != address(0) && artworks[tokenId].forSale) {
            artworks[tokenId].forSale = false;
            emit SaleToggled(tokenId, false);
        }
    }

    /// @dev 用 call 付款，避免 transfer 只转发 2300 gas 导致合约收款方失败。
    function _pay(address to, uint256 amount) private {
        if (amount == 0) return;
        (bool ok,) = payable(to).call{value: amount}("");
        if (!ok) revert PaymentFailed(to);
    }
}
