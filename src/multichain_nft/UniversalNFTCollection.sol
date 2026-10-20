// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC721URIStorageUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @title 多链共用的 ERC721 集合
/// @notice 同一份实现按链配置手续费和批量上限，通过透明代理部署。链差异只来自 `ChainConfig`，不在铸造路径里写死 chainId。
/// @dev 存储只允许在末尾追加。OpenZeppelin 父合约使用 ERC-7201 命名空间，下面四个变量才是本合约的线性布局。
///      重入锁不用 OpenZeppelin 的 `ReentrancyGuard`：它的构造函数写存储，透明代理的升级检查会拒绝。
contract UniversalNFTCollection is Initializable, ERC721URIStorageUpgradeable, OwnableUpgradeable {
    struct ChainConfig {
        uint256 chainId;
        uint256 baseFee;
        uint256 maxBatchSize;
        bool supportsBatch;
        address feeRecipient;
    }

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    ChainConfig public chainConfig;
    uint256 private _nextTokenId;
    string private _baseTokenURI;
    /// @dev 0 和 `_NOT_ENTERED` 都表示未进入。代理不会跑构造函数，所以不能依赖构造时写成 1。
    uint256 private _reentrancyStatus;

    event Minted(address indexed to, uint256 indexed tokenId, uint256 fee);
    /// @notice 一次批量只打一条事件。每枚代币仍会由 ERC721 发出 Transfer。
    event BatchMint(address indexed minter, uint256 indexed firstTokenId, uint256 quantity, uint256 totalFee);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event ChainConfigUpdated(
        uint256 indexed chainId, uint256 baseFee, uint256 maxBatchSize, bool supportsBatch, address feeRecipient
    );

    error ChainIdMismatch(uint256 expected, uint256 actual);
    error InvalidFeeRecipient();
    error InvalidBatchConfig();
    error EmptyMetadata();
    error InsufficientFee(uint256 sent, uint256 required);
    error BatchNotSupported();
    error EmptyBatch();
    error BatchLimitExceeded(uint256 length, uint256 max);
    error NothingToWithdraw();
    error FeeTransferFailed();
    error RefundFailed();
    error ReentrantCall();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice 代理构造时调用一次。`config_.chainId` 必须等于当前链，避免把 Polygon 配置初始化到别的链上。
    function initialize(address initialOwner, string memory name_, string memory symbol_, ChainConfig memory config_)
        public
        initializer
    {
        if (bytes(name_).length == 0 || bytes(symbol_).length == 0) revert EmptyMetadata();
        _validateConfig(config_);

        __ERC721_init(name_, symbol_);
        __ERC721URIStorage_init();
        __Ownable_init(initialOwner);
        chainConfig = config_;
    }

    /// @notice 付费铸造一枚。多付的 ETH 退回。
    function mint(address to) public payable nonReentrant returns (uint256 tokenId) {
        uint256 fee = chainConfig.baseFee;
        if (msg.value < fee) revert InsufficientFee(msg.value, fee);

        tokenId = _mintNext(to);
        emit Minted(to, tokenId, fee);
        _refundExcess(fee);
    }

    /// @notice 按链配置决定是否允许批量，以及单笔最多铸多少。Gas 上限靠 `maxBatchSize`，不靠写死某条链。
    function batchMint(address[] calldata recipients) external payable nonReentrant {
        ChainConfig memory config = chainConfig;
        if (!config.supportsBatch) revert BatchNotSupported();

        uint256 count = recipients.length;
        if (count == 0) revert EmptyBatch();
        if (count > config.maxBatchSize) revert BatchLimitExceeded(count, config.maxBatchSize);

        uint256 totalFee = config.baseFee * count;
        if (msg.value < totalFee) revert InsufficientFee(msg.value, totalFee);

        uint256 firstTokenId = _nextTokenId;
        for (uint256 i = 0; i < count; ++i) {
            _mintNext(recipients[i]);
        }

        emit BatchMint(msg.sender, firstTokenId, count, totalFee);
        _refundExcess(totalFee);
    }

    /// @notice 把合约里的手续费转给 `feeRecipient`。谁都可以调用，收款地址固定。
    function withdrawFees() external nonReentrant {
        address recipient = chainConfig.feeRecipient;
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();

        emit FeesWithdrawn(recipient, amount);
        (bool ok,) = recipient.call{value: amount}("");
        if (!ok) revert FeeTransferFailed();
    }

    /// @notice 调整手续费和批量参数。chainId 在初始化时绑定，不能改。
    function setFeeConfig(uint256 baseFee, uint256 maxBatchSize, bool supportsBatch, address feeRecipient)
        external
        onlyOwner
    {
        ChainConfig memory config = ChainConfig({
            chainId: chainConfig.chainId,
            baseFee: baseFee,
            maxBatchSize: maxBatchSize,
            supportsBatch: supportsBatch,
            feeRecipient: feeRecipient
        });
        _validateConfig(config);
        chainConfig = config;
        emit ChainConfigUpdated(config.chainId, baseFee, maxBatchSize, supportsBatch, feeRecipient);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    function setTokenURI(uint256 tokenId, string calldata uri) external onlyOwner {
        _requireOwned(tokenId);
        _setTokenURI(tokenId, uri);
    }

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    function baseURI() external view returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice `quantity == 1` 是单枚价格；更大的数量会先检查这条链是否允许批量。
    function mintFee(uint256 quantity) external view returns (uint256) {
        if (quantity == 0) revert EmptyBatch();
        if (quantity > 1) {
            if (!chainConfig.supportsBatch) revert BatchNotSupported();
            if (quantity > chainConfig.maxBatchSize) revert BatchLimitExceeded(quantity, chainConfig.maxBatchSize);
        }
        return chainConfig.baseFee * quantity;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _mintNext(address to) private returns (uint256 tokenId) {
        tokenId = _nextTokenId;
        unchecked {
            // tokenId 从 0 递增，实际不可能溢出。
            _nextTokenId = tokenId + 1;
        }
        _safeMint(to, tokenId);
    }

    function _refundExcess(uint256 price) private {
        uint256 refund = msg.value - price;
        if (refund == 0) return;
        (bool ok,) = msg.sender.call{value: refund}("");
        if (!ok) revert RefundFailed();
    }

    function _validateConfig(ChainConfig memory config) private view {
        if (config.chainId != block.chainid) revert ChainIdMismatch(block.chainid, config.chainId);
        if (config.feeRecipient == address(0)) revert InvalidFeeRecipient();
        if (config.supportsBatch && config.maxBatchSize == 0) revert InvalidBatchConfig();
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrantCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }
}
