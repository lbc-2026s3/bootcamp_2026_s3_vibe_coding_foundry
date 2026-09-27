// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {JumpRateModel} from "./JumpRateModel.sol";
import {SimplePriceOracle} from "./SimplePriceOracle.sol";

/// @notice 两种资产的教学借贷池。USDC 提供流动性，WETH 做抵押。
contract LendingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 internal constant WAD = 1e18;

    IERC20 public immutable collateralToken;
    IERC20 public immutable borrowToken;
    SimplePriceOracle public immutable oracle;
    JumpRateModel public immutable model;
    uint256 public immutable collateralFactor;
    uint256 public immutable liquidationIncentive;
    /// @notice 一次清算最多能代还的债务比例。1e18 = 100%。0.5e18 表示仓位已资不抵债时，一笔 liquidate 最多还掉当前债务的 50%，剩下的要再发交易。
    uint256 public immutable closeFactor;
    /// @notice 借款利息里记入协议储备金的比例。1e18 = 100%。0.1e18 表示新利息的 10% 进 totalReserves，其余 90% 留在池子里，让存款份额更值钱。没人借款时利息为 0，储备金也不增加。
    uint256 public immutable reserveFactor;

    uint256 public totalShares;
    mapping(address user => uint256 shares) public sharesOf;
    uint256 public totalBorrows;
    uint256 public totalReserves;
    uint256 public borrowIndex;
    uint256 public accrualTimestamp;
    /// @notice 该用户锁进池子的抵押品数量，单位是 WETH。抵押品不计息。取出或被清算时减少。
    mapping(address user => uint256 amount) public collateralOf;
    /// @notice 该用户上次借款或还款时记下的债务，单位是 USDC。之后产生的利息不写回这里。
    /// 当前债务 = principalOf × 当前 borrowIndex / userIndexOf。
    mapping(address user => uint256 principal) public principalOf;
    /// @notice 写下 principalOf 那一刻的全池 borrowIndex。和现在的 borrowIndex 一比，就知道这笔本金之后滚了多少利息。
    mapping(address user => uint256 index) public userIndexOf;

    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error InsufficientCash();
    error InsufficientCollateral();
    error Unhealthy();
    error ZeroPrice();
    error RepayExceedsDebt();
    error IdenticalTokens();
    error InvalidParameter();
    error NoDebt();
    error NoShortfall();
    error RepayExceedsCloseFactor();
    error ZeroSeize();
    error SeizeExceedsCollateral();
    error InsufficientReserves();

    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount, uint256 debt, uint256 totalBorrows);
    event Repay(address indexed payer, address indexed borrower, uint256 amount, uint256 debt);
    event Liquidate(address indexed liquidator, address indexed borrower, uint256 repayAmount, uint256 seizeAmount);
    event AccrueInterest(uint256 borrowIndex, uint256 totalBorrows, uint256 totalReserves);
    event ReservesReduced(address indexed to, uint256 amount);

    constructor(
        IERC20 collateralToken_,
        IERC20 borrowToken_,
        SimplePriceOracle oracle_,
        JumpRateModel model_,
        uint256 collateralFactor_,
        uint256 liquidationIncentive_,
        uint256 closeFactor_,
        uint256 reserveFactor_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (address(collateralToken_) == address(borrowToken_)) revert IdenticalTokens();
        if (collateralFactor_ == 0 || collateralFactor_ > WAD) revert InvalidParameter();
        if (liquidationIncentive_ < WAD) revert InvalidParameter();
        if (closeFactor_ == 0 || closeFactor_ > WAD) revert InvalidParameter();
        if (reserveFactor_ > WAD) revert InvalidParameter();

        collateralToken = collateralToken_;
        borrowToken = borrowToken_;
        oracle = oracle_;
        model = model_;
        collateralFactor = collateralFactor_;
        liquidationIncentive = liquidationIncentive_;
        closeFactor = closeFactor_;
        reserveFactor = reserveFactor_;
        // 借款指数从 1.0（1e18）起，表示还没滚过利息。
        // 某人的债务 = 本金 × 当前 borrowIndex / 他借款或还款时记下的指数。
        // 之后每次计息，指数按借款利率往上乘。从 0 开始的话，后面永远乘不上，债务也无法用这个除法记账。
        borrowIndex = WAD;
        accrualTimestamp = block.timestamp;
    }

    /// @notice 池子里的可借资产余额。
    function cash() public view returns (uint256) {
        return borrowToken.balanceOf(address(this));
    }

    /// @notice 每份额可取回的可借资产。还没有份额时是 1:1。
    function exchangeRate() public view returns (uint256) {
        if (totalShares == 0) return WAD;
        return (cash() + totalBorrows - totalReserves) * WAD / totalShares;
    }

    /// @notice 当前已记账债务。不含这次调用才应该滚上的利息。
    function borrowBalanceStored(address user) public view returns (uint256) {
        uint256 principal = principalOf[user];
        if (principal == 0) return 0;
        return principal * borrowIndex / userIndexOf[user];
    }

    /// @notice 借款额度减去债务。不调用计息。
    function getAccountLiquidity(address user) public view returns (uint256 liquidityUsd, uint256 shortfallUsd) {
        (, uint256 debtUsd, uint256 maxDebtUsd) = _usdValues(collateralOf[user], borrowBalanceStored(user));
        if (maxDebtUsd > debtUsd) liquidityUsd = maxDebtUsd - debtUsd;
        else shortfallUsd = debtUsd - maxDebtUsd;
    }

    /// @notice 把利息滚到当前时间。没人调用时利息不会自己增长。
    function accrueInterest() external nonReentrant {
        _accrueInterest();
    }

    /// @notice 存入可借资产，按当前汇率获得份额。
    function deposit(uint256 assets) external nonReentrant {
        _accrueInterest();
        if (assets == 0) revert ZeroAmount();
        uint256 shares = assets * WAD / exchangeRate();
        if (shares == 0) revert ZeroShares();
        totalShares += shares;
        sharesOf[msg.sender] += shares;
        emit Deposit(msg.sender, assets, shares);
        borrowToken.safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @notice 按资产数量取回可借资产。烧掉的份额向上取整。
    function withdraw(uint256 assets) external nonReentrant {
        _accrueInterest();
        if (assets == 0) revert ZeroAmount();
        uint256 rate = exchangeRate();
        uint256 shares = (assets * WAD + rate - 1) / rate;
        if (sharesOf[msg.sender] < shares) revert InsufficientShares();
        if (cash() < assets) revert InsufficientCash();
        sharesOf[msg.sender] -= shares;
        totalShares -= shares;
        emit Withdraw(msg.sender, assets, shares);
        borrowToken.safeTransfer(msg.sender, assets);
    }

    /// @notice 存入抵押品。抵押品不计息。
    function depositCollateral(uint256 amount) external nonReentrant {
        _accrueInterest();
        if (amount == 0) revert ZeroAmount();
        collateralOf[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice 取回抵押品。取完后仓位必须仍然健康。
    function withdrawCollateral(uint256 amount) external nonReentrant {
        _accrueInterest();
        if (amount == 0) revert ZeroAmount();
        if (collateralOf[msg.sender] < amount) revert InsufficientCollateral();
        collateralOf[msg.sender] -= amount;
        _requireHealthy(collateralOf[msg.sender], borrowBalanceStored(msg.sender));
        emit CollateralWithdrawn(msg.sender, amount);
        collateralToken.safeTransfer(msg.sender, amount);
    }

    /// @notice 借出可借资产。新债务不能超过抵押品价值乘抵押率。
    function borrow(uint256 amount) external nonReentrant {
        _accrueInterest();
        if (amount == 0) revert ZeroAmount();
        if (cash() < amount) revert InsufficientCash();
        uint256 newDebt = borrowBalanceStored(msg.sender) + amount;
        _requireHealthy(collateralOf[msg.sender], newDebt);
        principalOf[msg.sender] = newDebt;
        userIndexOf[msg.sender] = borrowIndex;
        totalBorrows += amount;
        emit Borrow(msg.sender, amount, newDebt, totalBorrows);
        borrowToken.safeTransfer(msg.sender, amount);
    }

    /// @notice 替 borrower 偿还债务。amount 为 uint256 最大值时还清。
    function repay(address borrower, uint256 amount) external nonReentrant {
        _accrueInterest();
        uint256 debt = borrowBalanceStored(borrower);
        uint256 repayAmount = amount == type(uint256).max ? debt : amount;
        if (repayAmount == 0) revert ZeroAmount();
        if (repayAmount > debt) revert RepayExceedsDebt();
        _reduceDebt(borrower, debt, repayAmount);
        emit Repay(msg.sender, borrower, repayAmount, debt - repayAmount);
        borrowToken.safeTransferFrom(msg.sender, address(this), repayAmount);
    }

    /// @notice 仓位已有短亏时，代还最多 close factor 的债务，并按激励拿走抵押品。
    function liquidate(address borrower, uint256 repayAmount) external nonReentrant {
        _accrueInterest();
        uint256 debt = borrowBalanceStored(borrower);
        if (debt == 0) revert NoDebt();
        (, uint256 shortfallUsd) = getAccountLiquidity(borrower);
        if (shortfallUsd == 0) revert NoShortfall();

        uint256 maxRepay = debt * closeFactor / WAD;
        if (repayAmount == 0) revert ZeroAmount();
        if (repayAmount > maxRepay) revert RepayExceedsCloseFactor();

        uint256 borrowPrice = oracle.getPrice(address(borrowToken));
        uint256 collateralPrice = oracle.getPrice(address(collateralToken));
        if (borrowPrice == 0 || collateralPrice == 0) revert ZeroPrice();

        uint256 repayUsd = repayAmount * borrowPrice / WAD;
        uint256 seizeUsd = repayUsd * liquidationIncentive / WAD;
        uint256 seize = seizeUsd * WAD / collateralPrice;
        if (seize == 0) revert ZeroSeize();
        if (seize > collateralOf[borrower]) revert SeizeExceedsCollateral();

        collateralOf[borrower] -= seize;
        _reduceDebt(borrower, debt, repayAmount);
        emit Liquidate(msg.sender, borrower, repayAmount, seize);
        collateralToken.safeTransfer(msg.sender, seize);
        borrowToken.safeTransferFrom(msg.sender, address(this), repayAmount);
    }

    /// @notice 把记账的储备金转给 owner。现金和储备金同减，存款汇率不变。
    function reduceReserves(uint256 amount) external onlyOwner nonReentrant {
        _accrueInterest();
        if (amount == 0) revert ZeroAmount();
        if (amount > totalReserves) revert InsufficientReserves();
        if (amount > cash()) revert InsufficientCash();
        totalReserves -= amount;
        emit ReservesReduced(msg.sender, amount);
        borrowToken.safeTransfer(msg.sender, amount);
    }

    function _accrueInterest() internal {
        uint256 delta = block.timestamp - accrualTimestamp;
        if (delta == 0) return;

        uint256 borrowRate = model.getBorrowRate(cash(), totalBorrows, totalReserves);
        uint256 interest = totalBorrows * borrowRate * delta / WAD;
        totalBorrows += interest;
        totalReserves += interest * reserveFactor / WAD;
        borrowIndex += borrowIndex * borrowRate * delta / WAD;
        accrualTimestamp = block.timestamp;
        emit AccrueInterest(borrowIndex, totalBorrows, totalReserves);
    }

    function _reduceDebt(address borrower, uint256 debt, uint256 repayAmount) internal {
        uint256 newDebt = debt - repayAmount;
        principalOf[borrower] = newDebt == 0 ? 0 : newDebt;
        userIndexOf[borrower] = borrowIndex;
        totalBorrows -= repayAmount;
    }

    function _requireHealthy(uint256 collateralAmount, uint256 debt) internal view {
        (, uint256 debtUsd, uint256 maxDebtUsd) = _usdValues(collateralAmount, debt);
        if (debtUsd > maxDebtUsd) revert Unhealthy();
    }

    function _usdValues(uint256 collateralAmount, uint256 debt)
        internal
        view
        returns (uint256 collateralUsd, uint256 debtUsd, uint256 maxDebtUsd)
    {
        uint256 collateralPrice = oracle.getPrice(address(collateralToken));
        uint256 borrowPrice = oracle.getPrice(address(borrowToken));
        if (collateralPrice == 0 || borrowPrice == 0) revert ZeroPrice();
        collateralUsd = collateralAmount * collateralPrice / WAD;
        debtUsd = debt * borrowPrice / WAD;
        maxDebtUsd = collateralUsd * collateralFactor / WAD;
    }
}
