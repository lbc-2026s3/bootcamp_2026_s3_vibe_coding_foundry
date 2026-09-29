// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title OptionToken — 以 ETH 为标的的看涨期权 ERC20
/// @notice 项目方存入 ETH 按 1:1 发行期权；到期日当天持有人可用 USDT 按行权价兑换 ETH；
///         到期日结束后，项目方赎回剩余标的 ETH。
/// @dev `strikePrice` 为行权「1 个完整 ETH（1e18 wei / 1e18 期权）」所需的 USDT 最小单位数量。
///      例如 USDT 为 6 decimals、行权价 2000 USDT/ETH 时，传入 `2000e6`。
contract OptionToken is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice 行权支付代币（测试中用 USDT）
    IERC20 public immutable usdt;

    /// @notice 行权价：兑换 1 ETH 所需的 USDT 数量（按 USDT decimals）
    uint256 public immutable strikePrice;

    /// @notice 到期日起始时间戳；行权窗口为 `[expiry, expiry + 1 days)`
    uint256 public immutable expiry;

    /// @notice 项目方是否已执行过期赎回
    bool public redeemed;

    error ZeroAddress();
    error ZeroAmount();
    error ZeroStrike();
    error InvalidExpiry();
    error IssueClosed();
    error NotExerciseDay();
    error NotExpired();
    error AlreadyRedeemed();
    error EthTransferFailed();
    error DirectEthNotAllowed();
    error RenounceDisabled();

    event Issued(address indexed issuer, uint256 ethAmount, uint256 optionAmount);
    event Exercised(address indexed user, uint256 optionAmount, uint256 usdtPaid, uint256 ethReceived);
    event ExpiredAndRedeemed(address indexed issuer, uint256 optionsBurned, uint256 ethRedeemed);

    /// @param name_ 期权 Token 名称
    /// @param symbol_ 期权 Token 符号
    /// @param usdt_ 行权支付代币地址（如 USDT）
    /// @param strikePrice_ 行权价（USDT 最小单位 / 1 ETH）
    /// @param expiry_ 到期日起始时间戳（须晚于部署时刻）
    /// @param initialOwner 项目方地址
    constructor(
        string memory name_,
        string memory symbol_,
        address usdt_,
        uint256 strikePrice_,
        uint256 expiry_,
        address initialOwner
    ) ERC20(name_, symbol_) Ownable(initialOwner) {
        if (usdt_ == address(0) || initialOwner == address(0)) revert ZeroAddress();
        if (strikePrice_ == 0) revert ZeroStrike();
        if (expiry_ <= block.timestamp) revert InvalidExpiry();

        usdt = IERC20(usdt_);
        strikePrice = strikePrice_;
        expiry = expiry_;
    }

    /// @notice 行权窗口结束时间（不含）
    function exerciseDeadline() public view returns (uint256) {
        return expiry + 1 days;
    }

    /// @notice 当前是否处于到期日行权窗口
    function isExerciseDay() public view returns (bool) {
        return block.timestamp >= expiry && block.timestamp < exerciseDeadline();
    }

    /// @notice 预览行权 `optionAmount` 份期权所需支付的 USDT
    function previewExerciseCost(uint256 optionAmount) public view returns (uint256) {
        return (optionAmount * strikePrice) / 1 ether;
    }

    /// @notice 项目方存入 ETH，按 1:1 铸造期权 Token 给自己
    /// @dev 仅到期日前可发行；之后进入行权/过期阶段
    function issue() external payable onlyOwner {
        if (block.timestamp >= expiry) revert IssueClosed();
        if (msg.value == 0) revert ZeroAmount();

        _mint(msg.sender, msg.value);
        emit Issued(msg.sender, msg.value, msg.value);
    }

    /// @notice 用户在到期日当天行权：支付 USDT、销毁期权、领取等量 ETH
    /// @param amount 要行权的期权数量（wei，与 ETH 1:1）
    function exercise(uint256 amount) external nonReentrant {
        if (!isExerciseDay()) revert NotExerciseDay();
        if (amount == 0) revert ZeroAmount();

        uint256 usdtCost = previewExerciseCost(amount);
        if (usdtCost == 0) revert ZeroAmount();

        _burn(msg.sender, amount);

        usdt.safeTransferFrom(msg.sender, owner(), usdtCost);

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert EthTransferFailed();

        emit Exercised(msg.sender, amount, usdtCost, amount);
    }

    /// @notice 到期日结束后，项目方销毁自持剩余期权并赎回合约内全部 ETH
    /// @dev 用户未行权的期权在窗口结束后失效（无法再兑换标的）；对应 ETH 归项目方。
    ///
    /// 背景：issue 时合约按 1:1 锁住 ETH；用户若在到期日行权，会烧掉期权并取走对应 ETH。
    /// 窗口结束后，合约里剩下的 ETH = 从未被行权的期权所对应的抵押品，应全部归还项目方。
    /// 合约无法遍历并强行烧掉其他地址持有的期权 Token，所以只烧项目方自己手里还没卖掉的；
    /// 用户钱包里未行权的 Token 会变成「废纸」（exercise 已不可调用，也换不出 ETH）。
    function expireAndRedeem() external onlyOwner nonReentrant {
        // 1) 必须过了行权窗口 [expiry, expiry+1 days)，否则用户还可能在行权
        if (block.timestamp < exerciseDeadline()) revert NotExpired();
        // 2) 只允许赎回一次，防止重复把 ETH 转走
        if (redeemed) revert AlreadyRedeemed();

        // 先打标：后续即使有重入也不会再进赎回逻辑
        redeemed = true;

        // 3) 烧掉项目方自己还持有的未售出/未行权期权（清库存）
        //    注意：用户地址上的余额这里烧不到，只能靠「过期不可行权」让其失效
        uint256 optionsBurned = balanceOf(msg.sender);
        if (optionsBurned > 0) {
            _burn(msg.sender, optionsBurned);
        }

        // 4) 把合约里剩余的全部 ETH 抵押品打回项目方
        //    数量通常 = 未行权期权总量（含用户手里那些已失效的）对应的 ETH
        uint256 ethRedeemed = address(this).balance;
        if (ethRedeemed > 0) {
            (bool ok,) = payable(msg.sender).call{value: ethRedeemed}("");
            if (!ok) revert EthTransferFailed();
        }

        emit ExpiredAndRedeemed(msg.sender, optionsBurned, ethRedeemed);
    }

    /// @dev 禁止放弃所有权，避免过期后无人可赎回剩余 ETH
    function renounceOwnership() public pure override {
        revert RenounceDisabled();
    }

    /// @dev 拒绝直接转入 ETH；标的只能通过 `issue` 进入
    receive() external payable {
        revert DirectEthNotAllowed();
    }
}
