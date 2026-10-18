// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title DynamicColorNFT
/// @notice 全链上纯色动态 NFT。每枚 token 记下铸造时的 `block.timestamp`，
///         颜色下标是该时间戳对 7 取余：红、橙、黄、绿、青、蓝、紫。
///         `tokenURI` 每次调用都按这个链上时间戳重画 SVG，不把图片冻成外部链接。
contract DynamicColorNFT is ERC721 {
    using Strings for uint256;

    /// @notice 色谱长度。下标 0 到 6 依次是红橙黄绿青蓝紫。
    uint256 public constant COLOR_COUNT = 7;

    /// @notice 下一枚 tokenId，从 0 起，也是已铸造数量。
    uint256 private _nextTokenId;

    /// @notice tokenId => 铸造时的区块时间戳。铸造后不再改，图片只跟着它变。
    mapping(uint256 tokenId => uint256 mintedAt) public mintedAt;

    /// @notice 铸造成功。`colorIndex` 等于 `mintedAt % 7`。
    event ColorMinted(address indexed to, uint256 indexed tokenId, uint256 mintedAt, uint256 colorIndex);

    /// @notice 颜色下标超出 0..6。
    error InvalidColorIndex(uint256 index);

    /// @notice 名称 Dynamic Color，符号 DCLR。没有管理员，任何人都可以铸造。
    constructor() ERC721("Dynamic Color", "DCLR") {}

    /// @notice 给 `to` 铸造一枚纯色 NFT。颜色由当前区块时间戳对 7 取余决定。
    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextTokenId;
        unchecked {
            _nextTokenId = tokenId + 1;
        }

        uint256 timestamp = block.timestamp;
        uint256 colorIndex = timestamp % COLOR_COUNT;
        // 先记下时间戳，再安全铸造。接收方在回调里读到的颜色已经是最终值。
        mintedAt[tokenId] = timestamp;

        _safeMint(to, tokenId);
        emit ColorMinted(to, tokenId, timestamp, colorIndex);
    }

    /// @notice 已铸造数量。
    function totalSupply() public view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice 这枚 token 的颜色下标，0 到 6。
    function colorIndexOf(uint256 tokenId) public view returns (uint256) {
        _requireOwned(tokenId);
        return mintedAt[tokenId] % COLOR_COUNT;
    }

    /// @notice 下标对应的颜色名。0 红，1 橙，2 黄，3 绿，4 青，5 蓝，6 紫。
    function colorName(uint256 index) public pure returns (string memory) {
        if (index == 0) return unicode"红";
        if (index == 1) return unicode"橙";
        if (index == 2) return unicode"黄";
        if (index == 3) return unicode"绿";
        if (index == 4) return unicode"青";
        if (index == 5) return unicode"蓝";
        if (index == 6) return unicode"紫";
        revert InvalidColorIndex(index);
    }

    /// @notice 下标对应的纯色十六进制。顺序与 `colorName` 相同。
    function colorHex(uint256 index) public pure returns (string memory) {
        if (index == 0) return "#FF0000";
        if (index == 1) return "#FF7F00";
        if (index == 2) return "#FFFF00";
        if (index == 3) return "#00FF00";
        if (index == 4) return "#00FFFF";
        if (index == 5) return "#0000FF";
        if (index == 6) return "#800080";
        revert InvalidColorIndex(index);
    }

    /// @notice 这枚 token 的颜色名。
    function colorNameOf(uint256 tokenId) public view returns (string memory) {
        return colorName(colorIndexOf(tokenId));
    }

    /// @notice 这枚 token 的纯色十六进制。
    function colorHexOf(uint256 tokenId) public view returns (string memory) {
        return colorHex(colorIndexOf(tokenId));
    }

    /// @notice 纯色 SVG。`fill` 来自铸造时间戳，不是外部图片。
    function imageSvg(uint256 tokenId) public view returns (string memory) {
        _requireOwned(tokenId);
        return _svg(colorHex(mintedAt[tokenId] % COLOR_COUNT));
    }

    /// @notice `data:image/svg+xml;base64,...`，给 metadata 的 image 字段用。
    function imageURI(uint256 tokenId) public view returns (string memory) {
        return string.concat("data:image/svg+xml;base64,", Base64.encode(bytes(imageSvg(tokenId))));
    }

    /// @notice 返回 data URI。JSON 和里面的 SVG 都在这次调用里按链上时间戳生成。
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string.concat("data:application/json;base64,", Base64.encode(bytes(_metadataJson(tokenId))));
    }

    /// @dev 拼 metadata JSON。字段都由本合约生成，不含调用方传入的字符串。
    function _metadataJson(uint256 tokenId) internal view returns (string memory) {
        uint256 index = mintedAt[tokenId] % COLOR_COUNT;
        return string.concat(_jsonHead(tokenId), _jsonImage(index), _jsonAttributes(tokenId, index));
    }

    function _jsonHead(uint256 tokenId) private pure returns (string memory) {
        return string.concat(
            '{"name":"Dynamic Color #',
            tokenId.toString(),
            '","description":"',
            unicode"纯色动态 NFT。展示图由铸造时间戳对 7 取余决定，依次为红橙黄绿青蓝紫。",
            '","image":"'
        );
    }

    function _jsonImage(uint256 index) private pure returns (string memory) {
        return string.concat("data:image/svg+xml;base64,", Base64.encode(bytes(_svg(colorHex(index)))));
    }

    function _jsonAttributes(uint256 tokenId, uint256 index) private view returns (string memory) {
        return string.concat(
            '","attributes":[',
            '{"trait_type":"Color","value":"',
            colorName(index),
            '"},',
            '{"trait_type":"Color Index","value":',
            index.toString(),
            '},',
            '{"trait_type":"Mint Timestamp","value":',
            mintedAt[tokenId].toString(),
            '},',
            '{"trait_type":"Hex","value":"',
            colorHex(index),
            '"}]}'
        );
    }

    function _svg(string memory hexColor) private pure returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">',
            '<rect width="512" height="512" fill="',
            hexColor,
            '"/></svg>'
        );
    }
}
