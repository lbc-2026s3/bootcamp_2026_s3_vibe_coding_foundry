// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title AdvancedNFT
/// @notice 带链上属性的 ERC721。元数据放在 data URI 里，稀有度只允许 1 到 5。
contract AdvancedNFT is ERC721, Ownable {
    using Strings for uint256;

    /// @notice 一枚 NFT 的链上属性，会写进 tokenURI 的 JSON。
    struct NFTAttributes {
        /// @notice 展示名称。
        string name;
        /// @notice 描述文本。
        string description;
        /// @notice 图片地址，原样放进 metadata 的 image 字段。
        string image;
        /// @notice 稀有度，只允许 1 到 5，并计入 rarityCount。
        uint256 rarity;
        /// @notice 等级。
        uint256 level;
        /// @notice 战力。
        uint256 power;
        /// @notice 是否特殊款。metadata 里是布尔 trait。
        bool isSpecial;
    }

    /// @notice tokenId 对应的链上属性。
    mapping(uint256 tokenId => NFTAttributes) public tokenAttributes;
    /// @notice 每个稀有度已铸造的数量。下标 1 到 5 有效。
    mapping(uint256 rarity => uint256 count) public rarityCount;

    /// @dev 下一枚要铸造的 tokenId，从 0 起。
    uint256 private _nextTokenId;

    /// @notice 铸造成功。
    event NFTMinted(address indexed to, uint256 indexed tokenId, NFTAttributes attributes);
    /// @notice 已有 NFT 的属性被覆盖。
    event AttributesUpdated(uint256 indexed tokenId, NFTAttributes attributes);

    /// @notice 名称 AdvancedNFT，符号 ANFT。部署者成为 owner。
    constructor() ERC721("AdvancedNFT", "ANFT") Ownable(msg.sender) {}

    /// @notice 铸造一枚带属性的 NFT。tokenId 从 0 递增。
    function mintNFT(
        address to,
        string memory name,
        string memory description,
        string memory image,
        uint256 rarity,
        uint256 level,
        uint256 power,
        bool isSpecial
    ) public onlyOwner returns (uint256) {
        require(rarity >= 1 && rarity <= 5, "Invalid rarity");

        uint256 tokenId = _nextTokenId;
        unchecked {
            _nextTokenId = tokenId + 1;
        }

        NFTAttributes memory attributes = NFTAttributes({
            name: name,
            description: description,
            image: image,
            rarity: rarity,
            level: level,
            power: power,
            isSpecial: isSpecial
        });
        tokenAttributes[tokenId] = attributes;
        rarityCount[rarity] += 1;

        _safeMint(to, tokenId);
        emit NFTMinted(to, tokenId, attributes);
        return tokenId;
    }

    /// @notice 覆盖已铸造 NFT 的属性，并同步稀有度计数。
    function updateAttributes(
        uint256 tokenId,
        string memory name,
        string memory description,
        string memory image,
        uint256 rarity,
        uint256 level,
        uint256 power,
        bool isSpecial
    ) public onlyOwner {
        _requireOwned(tokenId);
        require(rarity >= 1 && rarity <= 5, "Invalid rarity");

        uint256 oldRarity = tokenAttributes[tokenId].rarity;
        rarityCount[oldRarity] -= 1;

        NFTAttributes memory attributes = NFTAttributes({
            name: name,
            description: description,
            image: image,
            rarity: rarity,
            level: level,
            power: power,
            isSpecial: isSpecial
        });
        tokenAttributes[tokenId] = attributes;
        rarityCount[rarity] += 1;

        emit AttributesUpdated(tokenId, attributes);
    }

    /// @notice 读取已铸造 NFT 的属性。
    function getAttributes(uint256 tokenId) public view returns (NFTAttributes memory) {
        _requireOwned(tokenId);
        return tokenAttributes[tokenId];
    }

    /// @notice 下标 1 到 5 是各稀有度的数量，下标 0 不用。
    function getRarityStats() public view returns (uint256[6] memory stats) {
        for (uint256 i = 1; i <= 5; ++i) {
            stats[i] = rarityCount[i];
        }
    }

    /// @notice 已铸造数量，等于下一个 tokenId。
    function totalSupply() public view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice 返回 data URI。JSON 经 Base64 编码，不依赖外部服务器。
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // 未铸造的 tokenId 没有属性。
        _requireOwned(tokenId);
        // 前缀声明这是 JSON，后面是 metadata 的 Base64。钱包解码后就能读名字和图片地址。
        return
            string.concat(
                "data:application/json;base64,", Base64.encode(bytes(_metadataJson(tokenAttributes[tokenId])))
            );
    }

    /// @dev 把属性拼成 metadata JSON。name、description、image 会转义。
    function _metadataJson(NFTAttributes memory attributes) internal pure returns (string memory) {
        // 稀有度、等级、战力是数字 trait。Special 是布尔值，JSON 里不加引号。
        // 参考格式：https://quixotic-maroon-clownfish.myfilebase.com/ipfs/QmZRHXSmiy7hxXsyAyE9pCMBEteQY5qKTjWQ48BDoYYVHP
        return string.concat(
            '{"name":"',
            _escapeJson(attributes.name),
            '","description":"',
            _escapeJson(attributes.description),
            '","image":"',
            _escapeJson(attributes.image),
            '","attributes":[',
            _trait("Rarity", attributes.rarity),
            ",",
            _trait("Level", attributes.level),
            ",",
            _trait("Power", attributes.power),
            ',{"trait_type":"Special","value":',
            attributes.isSpecial ? "true" : "false",
            "}]}"
        );
    }

    /// @dev 拼一个数值 trait。traitType 由本合约写死，不做转义。
    /// 结果形如 {"trait_type":"Rarity","value":3}
    function _trait(string memory traitType, uint256 value) internal pure returns (string memory) {
        return string.concat('{"trait_type":"', traitType, '","value":', value.toString(), "}");
    }

    /// @dev 转义会破坏 JSON 字符串的字符，避免 name / description / image 把元数据截断。
    function _escapeJson(string memory input) internal pure returns (string memory) {
        bytes memory data = bytes(input);
        // 引号、反斜杠和换行都要多写一个字符，先数出需要加长多少。
        uint256 extra;
        for (uint256 i = 0; i < data.length; ++i) {
            bytes1 char = data[i];
            if (char == '"' || char == "\\" || char == "\n" || char == "\r" || char == "\t") {
                extra += 1;
            }
        }
        // 没有这些字符就原样返回，避免再拷贝一遍。
        if (extra == 0) return input;

        // 按加长后的长度一次分配，再把转义结果写进去。
        bytes memory out = new bytes(data.length + extra);
        uint256 j;
        for (uint256 i = 0; i < data.length; ++i) {
            bytes1 char = data[i];
            // " 和 \ 前面加反斜杠；换行、回车、制表符写成 \n、\r、\t。
            if (char == '"') {
                out[j++] = "\\";
                out[j++] = '"';
            } else if (char == "\\") {
                out[j++] = "\\";
                out[j++] = "\\";
            } else if (char == "\n") {
                out[j++] = "\\";
                out[j++] = "n";
            } else if (char == "\r") {
                out[j++] = "\\";
                out[j++] = "r";
            } else if (char == "\t") {
                out[j++] = "\\";
                out[j++] = "t";
            } else {
                out[j++] = char;
            }
        }
        return string(out);
    }
}
