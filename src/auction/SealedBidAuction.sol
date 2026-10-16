// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title SealedBidAuction — 首价密封拍卖
/// @notice 公开出价的金额写在交易里，进内存池就能被看见，别人可以加一点点并买到更靠前的排序。
///         这里改成两段窗口，出价在提交期结束前一直是密封的：
///
///         1. 提交期只收下 `hashBid(bidder, bidAmount, secret)`。链上没有金额。
///            哈希里带上出价人地址：披露交易里的金额和秘密是公开的，别人抄不走你的承诺。
///         2. 披露期才交真实金额。`secret` 必须和提交时一致，并且 `msg.value` 必须等于该金额。
///            提交期已经关闭，看见别人的价也不能再交一份新的承诺。
///
///         成交价是赢家自己的出价。相同价格时，先披露的人保持领先。
///         每人另交一笔相同的保证金，金额本身不暴露出价。披露成功后保证金退回；
///         提交了却不披露的，保证金给卖家，避免看见别人的价之后弃标。
/// @dev 输家和卖家都自己来 `withdraw`。合约不主动转账，避免退款时被重入。
contract SealedBidAuction is ReentrancyGuard {
    enum Phase {
        Commit,
        Reveal,
        Ended
    }

    address public immutable seller;
    uint256 public immutable commitDeadline;
    uint256 public immutable revealDeadline;
    /// @notice 每位出价人在提交时锁定的保证金。所有人相同，所以看不出谁出得更高。可以是 0。
    uint256 public immutable bidBond;

    address public highestBidder;
    uint256 public highestBid;
    bool public finalized;

    mapping(address bidder => bytes32 commitment) public commitments;
    mapping(address bidder => bool committed) public hasCommitted;
    mapping(address bidder => uint256 amount) public bids;
    mapping(address account => uint256 amount) public pendingReturns;

    /// @notice 付过保证金的人数。覆盖承诺不会增加。
    uint256 public commitCount;
    uint256 public revealCount;

    error ZeroDuration();
    error CommitPhaseOver();
    error NotRevealPhase();
    error AuctionNotEnded();
    error SellerCannotBid();
    error EmptyCommitment();
    error IncorrectBond(uint256 expected, uint256 actual);
    error NoCommitment();
    error AlreadyRevealed();
    error InvalidReveal();
    error ZeroBid();
    error IncorrectPayment(uint256 expected, uint256 actual);
    error AlreadyFinalized();
    error NothingToWithdraw();
    error TransferFailed();

    event Committed(address indexed bidder, bytes32 commitment);
    event BidRevealed(address indexed bidder, uint256 amount);
    event AuctionFinalized(address indexed winner, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    /// @param commitDuration 提交期长度，从部署时的 `block.timestamp` 起算
    /// @param revealDuration 披露期长度，紧接在提交期之后
    /// @param bidBond_ 提交保证金。传 0 表示不收保证金
    constructor(uint256 commitDuration, uint256 revealDuration, uint256 bidBond_) {
        if (commitDuration == 0 || revealDuration == 0) revert ZeroDuration();

        seller = msg.sender;
        commitDeadline = block.timestamp + commitDuration;
        revealDeadline = commitDeadline + revealDuration;
        bidBond = bidBond_;
    }

    /// @notice 当前所处窗口。`commitDeadline` 那一秒起进入披露期，`revealDeadline` 那一秒起结束。
    function phase() public view returns (Phase) {
        if (block.timestamp < commitDeadline) return Phase.Commit;
        if (block.timestamp < revealDeadline) return Phase.Reveal;
        return Phase.Ended;
    }

    /// @notice 链下用同一公式生成承诺。`secret` 用足够长的随机数，不要用小整数凑。
    function hashBid(address bidder, uint256 bidAmount, bytes32 secret) public pure returns (bytes32) {
        return keccak256(abi.encode(bidder, bidAmount, secret));
    }

    /// @notice 提交或覆盖承诺。第一次调用必须带上恰好 `bidBond` 的 ETH，覆盖时不再付款。
    function commit(bytes32 commitment) external payable {
        if (phase() != Phase.Commit) revert CommitPhaseOver();
        if (msg.sender == seller) revert SellerCannotBid();
        if (commitment == bytes32(0)) revert EmptyCommitment();

        uint256 expectedBond = hasCommitted[msg.sender] ? 0 : bidBond;
        if (msg.value != expectedBond) revert IncorrectBond(expectedBond, msg.value);

        if (!hasCommitted[msg.sender]) {
            hasCommitted[msg.sender] = true;
            commitCount += 1;
        }

        commitments[msg.sender] = commitment;
        emit Committed(msg.sender, commitment);
    }

    /// @notice 披露承诺对应的出价，并打入等额 ETH。提交期结束前、拍卖结束后都不能调用。
    function reveal(uint256 bidAmount, bytes32 secret) external payable {
        if (phase() != Phase.Reveal) revert NotRevealPhase();
        if (!hasCommitted[msg.sender]) revert NoCommitment();
        if (bids[msg.sender] != 0) revert AlreadyRevealed();
        if (hashBid(msg.sender, bidAmount, secret) != commitments[msg.sender]) revert InvalidReveal();
        if (bidAmount == 0) revert ZeroBid();
        if (msg.value != bidAmount) revert IncorrectPayment(bidAmount, msg.value);

        bids[msg.sender] = bidAmount;
        revealCount += 1;

        if (bidAmount > highestBid) {
            address previousBidder = highestBidder;
            if (previousBidder != address(0)) {
                pendingReturns[previousBidder] += highestBid + bidBond;
            }
            highestBid = bidAmount;
            highestBidder = msg.sender;
        } else {
            pendingReturns[msg.sender] += bidAmount + bidBond;
        }

        emit BidRevealed(msg.sender, bidAmount);
    }

    /// @notice 披露期结束后结算。任何人都能调用。卖家拿走最高出价，以及没来披露的保证金。
    function finalize() external {
        if (finalized) revert AlreadyFinalized();
        _finalize();
    }

    /// @notice 取回自己的退款或卖家收益。还没结算时会先结算；披露期结束前调用会回滚。
    function withdraw() external nonReentrant {
        if (!finalized) _finalize();

        uint256 amount = pendingReturns[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        pendingReturns[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    /// @dev 赢家的出价划给卖家，赢家只拿回保证金。弃标的保证金一并给卖家。
    function _finalize() private {
        if (block.timestamp < revealDeadline) revert AuctionNotEnded();

        finalized = true;

        uint256 forfeitedBonds = (commitCount - revealCount) * bidBond;
        uint256 proceeds = highestBid + forfeitedBonds;
        if (proceeds != 0) pendingReturns[seller] += proceeds;
        if (highestBidder != address(0) && bidBond != 0) {
            pendingReturns[highestBidder] += bidBond;
        }

        emit AuctionFinalized(highestBidder, highestBid);
    }
}
