// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import {NFTMarketPermitV1} from "./NFTMarketPermitV1.sol";

/// @notice V2：在 V1 上增加卖家离线签名上架 `permitList`，并追加 `version` 存储变量
/// @dev 推荐先 `setApprovalForAll(market, true)` 一次；也可对单个 tokenId `approve(market)` 后签名上架
/// @dev 签名字段: seller、tokenId、price、nonce、deadline；nonce 走 OZ Nonces（与 permitBuy 共用按地址递增）
/// @dev 存储：仅在 V1 布局（含 V1 `__gap`）之后追加 `version`，不得插入/重排 V1 变量
/// @custom:oz-upgrades-from NFTMarketPermitV1
contract NFTMarketPermitV2 is NFTMarketPermitV1 {
    /// @notice 合约版本号（升级到 V2 后由 `initializeV2` 写入）
    uint256 public version;

    /// @dev EIP-712 typehash: PermitList(address seller,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)
    bytes32 public constant PERMIT_LIST_TYPEHASH = keccak256(
        "PermitList(address seller,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"
    );

    error NotApproved(address seller, uint256 tokenId, address operator);

    event PermitListAuthorized(
        address indexed seller, uint256 indexed tokenId, uint256 price, uint256 nonce, uint256 deadline
    );

    /// @notice 升级初始化：写入 version=2（V1 已在 proxy 上 initialize 过，无需再调父 initializer）
    function initializeV2() public reinitializer(2) onlyOwner {
        version = 2;
    }

    /// @notice 凭卖家离线签名上架：需事先授权市场（`setApprovalForAll` 或对该 tokenId `approve`）
    /// @dev 任意地址可代提交（relayer）；验签恢复地址必须等于 `seller`，且 seller 须为 NFT 当前持有人
    /// @param seller 签名卖家（也是挂单 seller）
    /// @param tokenId 要上架的 NFT
    /// @param price 标价（TOKEN 数量）
    /// @param deadline 签名过期时间（unix 秒）
    /// @param v 签名 v
    /// @param r 签名 r
    /// @param s 签名 s
    function permitList(
        address seller,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        if (block.timestamp > deadline) revert SignatureExpired(deadline, block.timestamp);
        if (seller == address(0)) revert ZeroAddress();
        if (price == 0) revert ZeroPrice();
        if (listings[tokenId].price != 0) revert AlreadyListed();
        if (nft.ownerOf(tokenId) != seller) revert NotOwner();
        if (!_isApprovedToMarket(seller, tokenId)) {
            revert NotApproved(seller, tokenId, address(this));
        }

        // 与 permitBuy / ERC20Permit 一致：先 _useNonce 再验签（CEI）
        uint256 nonce = _useNonce(seller);
        bytes32 structHash = keccak256(abi.encode(PERMIT_LIST_TYPEHASH, seller, tokenId, price, nonce, deadline));
        bytes32 digest = _hashTypedDataV4(structHash);
        address recovered = ECDSA.recover(digest, v, r, s);
        if (recovered != seller) revert InvalidSigner(recovered, seller);

        listings[tokenId] = Listing({seller: seller, price: price});
        emit PermitListAuthorized(seller, tokenId, price, nonce, deadline);
        emit Listed(tokenId, seller, price);

        // 依赖 approve / setApprovalForAll；回调走 onERC721Received 的「已有挂单」分支
        nft.safeTransferFrom(seller, address(this), tokenId);
    }

    /// @dev ERC721：operator 获批全部，或该 tokenId 的 getApproved 指向本市场
    function _isApprovedToMarket(address seller, uint256 tokenId) private view returns (bool) {
        return nft.isApprovedForAll(seller, address(this)) || nft.getApproved(tokenId) == address(this);
    }

    /// @dev 预留给 V2 后续追加变量；与 V1 的 `__gap` 互不占用（接在 V1 布局之后）
    uint256[50] private __gap;
}
