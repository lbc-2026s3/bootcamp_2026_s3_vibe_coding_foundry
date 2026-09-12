// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Nonces} from "openzeppelin-contracts/contracts/utils/Nonces.sol";

import {NFTMarket} from "./NFTMarket.sol";

/// @notice NFTMarketPermit: 继承 NFTMarket，额外支持离线白名单签名购买
/// @dev 保留父合约全部购买路径（buyNFT / ERC1363）；另增 permitBuy：需 owner 离线 EIP-712 授权
/// @dev 签名字段: buyer、tokenId、nonce、deadline；nonce 使用 OZ Nonces 防重放
contract NFTMarketPermit is NFTMarket, EIP712, Ownable, Nonces {
    /// @dev EIP-712 typehash: PermitBuy(address buyer,uint256 tokenId,uint256 nonce,uint256 deadline)
    bytes32 public constant PERMIT_BUY_TYPEHASH =
        keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 nonce,uint256 deadline)");

    error SignatureExpired(uint256 deadline, uint256 current);
    error InvalidSigner(address recovered, address expected);

    event PermitBuyAuthorized(address indexed buyer, uint256 indexed tokenId, uint256 nonce, uint256 deadline);

    /// @param paymentToken_ 支付代币
    /// @param nft_ 交易的 NFT
    /// @param initialOwner 白名单签名者（owner），离线签 PermitBuy
    constructor(IERC20 paymentToken_, IERC721 nft_, address initialOwner)
        NFTMarket(paymentToken_, nft_)
        EIP712("NFTMarketPermit", "1")
        Ownable(initialOwner)
    {}

    /// @notice EIP-712 domain separator（便于链下拼装 typed data）
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @notice 持有有效 owner 白名单签名时购买（其他购买路径仍可用）
    /// @param tokenId 要购买的 NFT
    /// @param amount 支付 TOKEN 数量（须 >= 标价）
    /// @param deadline 签名过期时间（unix 秒）
    /// @param v 签名 v
    /// @param r 签名 r
    /// @param s 签名 s
    function permitBuy(uint256 tokenId, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        nonReentrant
    {
        if (block.timestamp > deadline) revert SignatureExpired(deadline, block.timestamp);

        // 与 ERC20Permit 一致：先 _useNonce 再验签（CEI）
        uint256 nonce = _useNonce(msg.sender);
        bytes32 structHash = keccak256(abi.encode(PERMIT_BUY_TYPEHASH, msg.sender, tokenId, nonce, deadline));
        bytes32 digest = _hashTypedDataV4(structHash);
        address recovered = ECDSA.recover(digest, v, r, s);
        if (recovered != owner()) revert InvalidSigner(recovered, owner());

        emit PermitBuyAuthorized(msg.sender, tokenId, nonce, deadline);
        _buyWithPull(msg.sender, tokenId, amount);
    }
}
