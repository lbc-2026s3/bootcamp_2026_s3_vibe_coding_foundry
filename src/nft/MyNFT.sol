// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title MyNFT
/// @notice 付费铸造的 ERC721。单枚 0.08 ETH，上限 10000。指定 token URI 优先于 baseURI。
contract MyNFT is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant MINT_PRICE = 0.08 ether;

    uint256 private _nextTokenId;
    string private _baseTokenURI;
    mapping(uint256 tokenId => string uri) private _tokenURIs;

    event TokenMinted(address indexed to, uint256 indexed tokenId);
    event BaseURIUpdated(string newBaseURI);
    event TokenURIUpdated(uint256 indexed tokenId, string tokenURI);

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) Ownable(msg.sender) {}

    /// @notice 支付铸造一枚 NFT。多付的 ETH 留在合约里，由 owner 提取。
    function mint(address to) public payable nonReentrant returns (uint256) {
        require(_nextTokenId < MAX_SUPPLY, "Max supply reached");
        require(msg.value >= MINT_PRICE, "Insufficient payment");
        return _mintNext(to);
    }

    /// @notice 一次最多铸造 10 枚，按枚计价。
    function mintBatch(address to, uint256 quantity) public payable nonReentrant returns (uint256[] memory) {
        require(quantity > 0 && quantity <= 10, "Invalid quantity");
        // token id 从 0 起，最后一枚是 MAX_SUPPLY - 1。相等表示这批刚好铸满，不会多铸。
        require(_nextTokenId + quantity <= MAX_SUPPLY, "Exceeds max supply");
        require(msg.value >= MINT_PRICE * quantity, "Insufficient payment");

        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; ++i) {
            tokenIds[i] = _mintNext(to);
        }
        return tokenIds;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
        emit BaseURIUpdated(baseURI);
    }

    /// @notice 为已存在的 token 设置完整 URI。设置后不再拼接 baseURI。
    function setTokenURI(uint256 tokenId, string memory uri) public onlyOwner {
        _requireOwned(tokenId);
        _tokenURIs[tokenId] = uri;
        emit TokenURIUpdated(tokenId, uri);
    }

    function totalSupply() public view returns (uint256) {
        return _nextTokenId;
    }

    function withdraw() public onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success,) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        if (bytes(_tokenURIs[tokenId]).length > 0) {
            return _tokenURIs[tokenId];
        }
        return string.concat(_baseURI(), tokenId.toString());
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _mintNext(address to) private returns (uint256 tokenId) {
        tokenId = _nextTokenId;
        require(tokenId < MAX_SUPPLY, "Max supply reached");
        unchecked {
            _nextTokenId = tokenId + 1;
        }
        _safeMint(to, tokenId);
        emit TokenMinted(to, tokenId);
    }
}
