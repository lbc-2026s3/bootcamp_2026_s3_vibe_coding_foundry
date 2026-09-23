// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router02} from "uniswapv2/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "uniswapv2/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "uniswapv2/interfaces/IUniswapV2Pair.sol";
import {MemeToken} from "./MemeToken.sol";

/// @notice Meme LaunchPad：固定价 mint 期募资进 Uniswap V2 并烧 LP；达标后毕业，仅允许池内买入。
/// @dev mint 期：1% 手续费记入 pendingFees；99% + 按 mint 价折算 meme 加池；找零退回调用者。
contract LaunchPad is ReentrancyGuard {
    uint256 public constant CREATOR_FEE_BPS = 100; // 1%
    uint256 public constant BPS_DENOMINATOR = 10_000;
    address public constant DEAD = address(0xdead);

    error EmptySymbol();
    error InvalidSupply();
    error InvalidPrice();
    error InvalidGraduation();
    error ZeroRouter();
    error UnknownMeme();
    error InvalidPayment();
    error ZeroValue();
    error EthTransferFailed();
    error Expired();
    error AlreadyGraduated();
    error InsufficientMintRoom();
    error NoFees();

    address public immutable implementation;
    IUniswapV2Router02 public immutable router;
    address public immutable WETH;
    address public immutable uniFactory;

    mapping(address token => bool) public isMeme;
    /// @notice 累计注入流动性的 ETH 目标，达到后毕业（关闭 mintMeme）
    mapping(address token => uint256) public graduationEth;
    /// @notice 已累计用于加池的 ETH（按 mint 意图计入，非 Router 实际 used）
    mapping(address token => uint256) public ethRaisedForLp;
    mapping(address token => bool) public graduated;
    /// @notice creator 待领取手续费（pull payment，避免 creator 拒收 ETH 卡死 mint）
    mapping(address account => uint256) public pendingFees;

    event MemeDeployed(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 maxSupply,
        uint256 perMint,
        uint256 price,
        uint256 graduationEth
    );
    event MemeMinted(
        address indexed token,
        address indexed minter,
        uint256 memeAmount,
        uint256 ethPaid,
        uint256 ethForLiquidity,
        uint256 memeForLiquidity,
        uint256 ethForCreator
    );
    event MemeBought(address indexed token, address indexed buyer, uint256 ethIn, uint256 memeOut);
    event LiquidityAdded(address indexed token, uint256 amountToken, uint256 amountETH, uint256 liquidity);
    event Graduated(address indexed token, uint256 ethRaisedForLp);
    event FeesClaimed(address indexed account, uint256 amount);

    constructor(address router_) {
        if (router_ == address(0)) revert ZeroRouter();
        router = IUniswapV2Router02(router_);
        WETH = IUniswapV2Router02(router_).WETH();
        uniFactory = IUniswapV2Router02(router_).factory();
        implementation = address(new MemeToken(address(this)));
    }

    /// @dev 仅接受 Router 加池退回的 ETH；其它转入也会被 bal0 会计留下，不会误退给 minter
    receive() external payable {}

    /// @notice 克隆部署 Meme。
    /// @param symbol token 代号
    /// @param maxSupply 铸造上限（须能被单次 mint 消耗量整除，避免尾量卡死）
    /// @param perMint 每次 mint 给买家的数量
    /// @param price 每次 mint 支付的 ETH（wei）
    /// @param graduationEth_ 累计加池 ETH 达到该值后毕业；须 > 0
    ///
    /// 示例：`deployMeme("DOGE", 1990e18 * 10, 1000e18, 1 ether, 10 ether)`
    /// — 单次消耗 1000+990 枚；graduation 约 10 次 mint（每次 ~0.99 ETH 进池）后关闭 mint。
    function deployMeme(
        string memory symbol,
        uint256 maxSupply,
        uint256 perMint,
        uint256 price,
        uint256 graduationEth_
    ) external returns (address token) {
        if (bytes(symbol).length == 0) revert EmptySymbol();
        if (price == 0) revert InvalidPrice();
        if (graduationEth_ == 0) revert InvalidGraduation();
        if (maxSupply == 0 || perMint == 0 || perMint > maxSupply) revert InvalidSupply();

        uint256 memeForLp = _memeForLiquidity(price, perMint);
        if (memeForLp == 0) revert InvalidSupply();
        uint256 mintUnit = perMint + memeForLp;
        if (maxSupply < mintUnit) revert InvalidSupply();
        // 避免尾量不足以再 mint 却永远占着 maxSupply
        if (maxSupply % mintUnit != 0) revert InvalidSupply();

        token = Clones.clone(implementation);
        isMeme[token] = true;
        graduationEth[token] = graduationEth_;
        MemeToken(token).initialize(msg.sender, symbol, maxSupply, perMint, price);

        emit MemeDeployed(token, msg.sender, symbol, maxSupply, perMint, price, graduationEth_);
    }

    /// @notice 固定价 mint（毕业前）。ETH：1% → pendingFees[creator]；其余尽量加池；找零退回调用者。
    /// @param amountTokenMin / amountETHMin 加池滑点保护（首次可传精确期望值）
    /// @param deadline 交易截止时间
    function mintMeme(address tokenAddr, uint256 amountTokenMin, uint256 amountETHMin, uint256 deadline)
        external
        payable
        nonReentrant
    {
        if (block.timestamp > deadline) revert Expired();
        if (!isMeme[tokenAddr]) revert UnknownMeme();
        if (graduated[tokenAddr]) revert AlreadyGraduated();

        MemeToken token = MemeToken(tokenAddr);
        uint256 price = token.price();
        uint256 perMint = token.perMint();
        if (msg.value != price) revert InvalidPayment();

        uint256 ethForCreator = (msg.value * CREATOR_FEE_BPS) / BPS_DENOMINATOR;
        // 在 DEX 上添加流动性的 ETH 和 meme
        uint256 ethForLp = msg.value - ethForCreator;
        uint256 memeForLp = (ethForLp * perMint) / price;

        uint256 remaining = token.maxSupply() - token.totalSupply();
        // perMint 给用户，memeForLp 给 LP 池
        if (remaining < perMint + memeForLp) revert InsufficientMintRoom();

        // 预存「外来 ETH」，退款时只退本笔产生的余额增量，避免扫走捐赠款
        uint256 bal0 = address(this).balance - msg.value;

        // 铸造给用户
        token.mint(msg.sender, perMint);
        // 铸造给 LP 池
        token.mint(address(this), memeForLp);
        _addLiquidity(tokenAddr, memeForLp, ethForLp, amountTokenMin, amountETHMin, deadline);

        ethRaisedForLp[tokenAddr] += ethForLp;
        pendingFees[token.creator()] += ethForCreator;

        // 本笔应留给手续费的 ETH 仍在合约内；其余（含 Router 找零）退回调用者
        uint256 refund = address(this).balance - bal0 - ethForCreator;
        _sendEth(msg.sender, refund);

        emit MemeMinted(tokenAddr, msg.sender, perMint, msg.value, ethForLp, memeForLp, ethForCreator);

        _maybeGraduate(tokenAddr);
    }

    /// @notice 按 Uniswap V2 池价买 meme（需自行设 amountOutMin / deadline）。
    function buyMeme(address tokenAddr, uint256 amountOutMin, uint256 deadline) external payable nonReentrant {
        if (block.timestamp > deadline) revert Expired();
        if (!isMeme[tokenAddr]) revert UnknownMeme();
        if (msg.value == 0) revert ZeroValue();

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenAddr;

        uint256[] memory amounts =
            router.swapExactETHForTokens{value: msg.value}(amountOutMin, path, msg.sender, deadline);

        emit MemeBought(tokenAddr, msg.sender, msg.value, amounts[amounts.length - 1]);
    }

    /// @notice creator（或任何有 pending 的地址）领取手续费。
    function claimFees() external nonReentrant {
        uint256 amount = pendingFees[msg.sender];
        if (amount == 0) revert NoFees();
        pendingFees[msg.sender] = 0;
        _sendEth(msg.sender, amount);
        emit FeesClaimed(msg.sender, amount);
    }

    /// @dev 单次 mint 进池 meme 数量（与 mintMeme 相同）。
    function _memeForLiquidity(uint256 price, uint256 perMint) internal pure returns (uint256) {
        uint256 ethForCreator = (price * CREATOR_FEE_BPS) / BPS_DENOMINATOR;
        uint256 ethForLp = price - ethForCreator;
        return (ethForLp * perMint) / price;
    }

    function _maybeGraduate(address tokenAddr) internal {
        if (graduated[tokenAddr]) return;

        MemeToken token = MemeToken(tokenAddr);
        uint256 memeForLp = _memeForLiquidity(token.price(), token.perMint());
        uint256 mintUnit = token.perMint() + memeForLp;
        uint256 remaining = token.maxSupply() - token.totalSupply();

        bool hitRaise = ethRaisedForLp[tokenAddr] >= graduationEth[tokenAddr];
        bool soldOut = remaining < mintUnit;

        // 达到毕业条件
        //1. 达到累计加池 ETH 目标
        //2. 达到铸造上限，无法支撑下一次 mint
        if (hitRaise || soldOut) {
            graduated[tokenAddr] = true;
            emit Graduated(tokenAddr, ethRaisedForLp[tokenAddr]);
        }
    }

    function _addLiquidity(
        address token,
        uint256 amountToken,
        uint256 amountETH,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) internal {
        IERC20(token).approve(address(router), amountToken);

        (uint256 usedToken, uint256 usedETH, uint256 liquidity) = router.addLiquidityETH{value: amountETH}(
            token, amountToken, amountTokenMin, amountETHMin, address(0), deadline
        );

        // 销毁剩余的 meme, 避免滞留在本合约
        uint256 dustMeme = IERC20(token).balanceOf(address(this));
        if (dustMeme > 0) IERC20(token).transfer(DEAD, dustMeme);

        emit LiquidityAdded(token, usedToken, usedETH, liquidity);
    }

    function _sendEth(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert EthTransferFailed();
    }

    /// @notice 辅助：按当前池储备，给出去 amountETH 期望换到的 token 量（未含手续费精确报价可用 getAmountsOut）。
    function previewBuy(address tokenAddr, uint256 ethIn) external view returns (uint256 memeOut) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenAddr;
        uint256[] memory amounts = router.getAmountsOut(ethIn, path);
        return amounts[1];
    }

    /// @notice 辅助：首次加池时建议的 min（按 mint 价，可再自行打折）。
    function previewMintLpAmounts(address tokenAddr)
        external
        view
        returns (uint256 ethForLp, uint256 memeForLp)
    {
        if (!isMeme[tokenAddr]) revert UnknownMeme();
        MemeToken token = MemeToken(tokenAddr);
        uint256 price = token.price();
        ethForLp = price - (price * CREATOR_FEE_BPS) / BPS_DENOMINATOR;
        memeForLp = _memeForLiquidity(price, token.perMint());
    }

    /// @notice 池是否已存在（二次 mint 时 caller 应用 quote 设 min）。
    function hasPool(address tokenAddr) external view returns (bool) {
        return IUniswapV2Factory(uniFactory).getPair(tokenAddr, WETH) != address(0);
    }

    /// @notice 读池储备 (meme, weth)，无池返回 (0,0)。
    function getReserves(address tokenAddr) external view returns (uint256 reserveMeme, uint256 reserveWeth) {
        address pair = IUniswapV2Factory(uniFactory).getPair(tokenAddr, WETH);
        if (pair == address(0)) return (0, 0);
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        return token0 == tokenAddr ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
    }
}
