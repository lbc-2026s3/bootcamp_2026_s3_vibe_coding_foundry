// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import {NFTMarketPermit} from "./NFTMarketPermit.sol";

/// @notice AirdopMerkleNFTMarket: 用 MyTokenERC2612Permit 购买 NFT；白名单半价领取
/// @dev 继承 NFTMarketPermit（全部原购买路径仍可用）与 OpenZeppelin Multicall
/// @dev 推荐路径：multicall([permitPrePay, claimNFT]) 一笔完成授权 + 白名单领取
/// @dev 叶子编码: keccak256(bytes.concat(keccak256(abi.encode(account))))
contract AirdopMerkleNFTMarket is NFTMarketPermit, Multicall {
    using SafeERC20 for IERC20;

    /// @notice 白名单折扣：5000 = 50%
    uint256 public constant WHITELIST_PRICE_BPS = 5_000;

    /// @notice 构造时写入的白名单 Merkle root
    bytes32 public immutable merkleRoot;

    /// @notice 每个白名单地址仅能半价领取一次
    mapping(address => bool) public hasClaimed;

    error ZeroMerkleRoot();
    error NotWhitelisted(address account);
    error AlreadyClaimed(address account);
    error PermitFailed();
    error NotAirdropListing(address seller);

    event PermitPrePaid(address indexed owner, uint256 value, uint256 deadline);
    event NFTClaimed(address indexed account, uint256 indexed tokenId, uint256 paid);

    /// @param paymentToken_ 支付代币（须支持 ERC-2612 permit，如 MyTokenERC2612Permit）
    /// @param nft_ 交易的 NFT
    /// @param initialOwner 市场 owner（父合约 permitBuy 签名者）
    /// @param merkleRoot_ 白名单地址 Merkle root
    constructor(IERC20 paymentToken_, IERC721 nft_, address initialOwner, bytes32 merkleRoot_)
        NFTMarketPermit(paymentToken_, nft_, initialOwner)
    {
        if (merkleRoot_ == bytes32(0)) revert ZeroMerkleRoot();
        merkleRoot = merkleRoot_;
    }

    /// @notice 白名单叶子：keccak256(bytes.concat(keccak256(abi.encode(account))))
    /// @dev 与 MerkleWhitelist.leaf 一致。根/proof 用 MerkleWhitelist 按给定顺序组树（不对叶子排序）。
    ///      名单长度任意；不要用 OpenZeppelin JS StandardMerkleTree.of 的默认 sortLeaves=true。
    function whitelistLeaf(address account) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account))));
    }

    /// @notice 调用支付代币 permit，为本市场预授权（spender 固定为本合约）
    /// @dev permit 可被抢先上链；try/catch 避免重复 permit 导致整笔 multicall 失败
    function permitPrePay(uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        try IERC20Permit(address(paymentToken)).permit(msg.sender, address(this), value, deadline, v, r, s) {}
        catch {
            // 仅容忍抢先上链导致的重复 permit；签名无效且无足额 allowance 时仍失败
            if (paymentToken.allowance(msg.sender, address(this)) < value) revert PermitFailed();
        }
        emit PermitPrePaid(msg.sender, value, deadline);
    }

    /// @notice 仅白名单用户可调用：校验 Merkle proof 后，半价购买「市场 owner 上架」的 NFT
    /// @dev 素人挂单不走五折，请用 buyNFT / permitBuy 原价购买
    /// @param tokenId 要领取的 NFT
    /// @param merkleProof 对应 msg.sender 的 Merkle proof
    function claimNFT(uint256 tokenId, bytes32[] calldata merkleProof) external nonReentrant {
        if (hasClaimed[msg.sender]) revert AlreadyClaimed(msg.sender);
        if (!MerkleProof.verifyCalldata(merkleProof, merkleRoot, whitelistLeaf(msg.sender))) {
            revert NotWhitelisted(msg.sender);
        }

        Listing memory listing = listings[tokenId];
        if (listing.price == 0) revert NotListed();
        if (listing.seller != owner()) revert NotAirdropListing(listing.seller);

        // 白名单用户可以以50%的价格购买NFT
        uint256 paid = (listing.price * WHITELIST_PRICE_BPS) / 10_000;
        if (paid == 0) revert ZeroPrice();

        hasClaimed[msg.sender] = true;
        delete listings[tokenId];

        paymentToken.safeTransferFrom(msg.sender, listing.seller, paid);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Bought(tokenId, msg.sender, listing.seller, paid);
        emit NFTClaimed(msg.sender, tokenId, paid);
    }
}
