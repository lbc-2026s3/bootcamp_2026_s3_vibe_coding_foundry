// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {NoncesUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/NoncesUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

import {NFTMarketUpgradeable} from "./NFTMarketUpgradeable.sol";

/// @notice NFTMarketPermit 的 UUPS 可升级 V1：保留全部购买路径，另增 permitBuy
/// @dev 签名字段: buyer、tokenId、nonce、deadline；nonce 使用 OZ Nonces 防重放
/// @dev Ownable 保存「谁有权签发 PermitBuy」；upgrade 权同属 owner
contract NFTMarketPermitV1 is
    Initializable,
    NFTMarketUpgradeable,
    EIP712Upgradeable,
    OwnableUpgradeable,
    NoncesUpgradeable,
    UUPSUpgradeable
{
    /// @dev EIP-712 typehash: PermitBuy(address buyer,uint256 tokenId,uint256 nonce,uint256 deadline)
    bytes32 public constant PERMIT_BUY_TYPEHASH =
        keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 nonce,uint256 deadline)");

    error SignatureExpired(uint256 deadline, uint256 current);
    error InvalidSigner(address recovered, address expected);

    event PermitBuyAuthorized(address indexed buyer, uint256 indexed tokenId, uint256 nonce, uint256 deadline);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @param paymentToken_ 支付代币（如 MyTokenERC2612Permit）
    /// @param nft_ 交易的 NFT（如 MyERC721UpgradeableNFTV2 proxy）
    /// @param initialOwner 白名单签名者 / 升级权持有人
    function initialize(IERC20 paymentToken_, IERC721 nft_, address initialOwner) public initializer {
        __NFTMarket_init(paymentToken_, nft_);
        __EIP712_init("NFTMarketPermit", "1");
        __Ownable_init(initialOwner);
        __Nonces_init();
        // UUPSUpgradeable（非 upgradeable 包）无 __UUPSUpgradeable_init；与 MyERC721UpgradeableNFT 一致
    }

    /// @notice EIP-712 domain separator（便于链下拼装 typed data）
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @notice 持有有效 owner 白名单签名时购买（其他购买路径仍可用）
    function permitBuy(uint256 tokenId, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        nonReentrant
    {
        if (block.timestamp > deadline) revert SignatureExpired(deadline, block.timestamp);

        uint256 nonce = _useNonce(msg.sender);
        bytes32 structHash = keccak256(abi.encode(PERMIT_BUY_TYPEHASH, msg.sender, tokenId, nonce, deadline));
        bytes32 digest = _hashTypedDataV4(structHash);
        address recovered = ECDSA.recover(digest, v, r, s);
        if (recovered != owner()) revert InvalidSigner(recovered, owner());

        emit PermitBuyAuthorized(msg.sender, tokenId, nonce, deadline);
        _buyWithPull(msg.sender, tokenId, amount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    uint256[50] private __gap;
}
