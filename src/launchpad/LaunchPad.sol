// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router02} from "uniswapv2/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "uniswapv2/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "uniswapv2/interfaces/IUniswapV2Pair.sol";
import {MemeToken} from "./MemeToken.sol";

/// @notice 线上 LaunchPad 模式：mint 期锁 ETH；达标/售罄后一次性加 Uniswap V2 流动性并烧 LP；之后只能 buyMeme。
/// @dev mint：1% → pendingFees；99% 锁仓（ethRaisedForLp）并记账 memeReservedForLp；毕业时按 mint 价一次性 addLiquidityETH。
contract LaunchPad is ReentrancyGuard {
    uint256 public constant CREATOR_FEE_BPS = 100;
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
    error NotGraduated();
    error InsufficientMintRoom();
    error NoFees();
    error GraduationNotReady();

    address public immutable implementation;
    IUniswapV2Router02 public immutable router;
    address public immutable WETH;
    address public immutable uniFactory;

    mapping(address token => bool) public isMeme;
    mapping(address token => uint256) public graduationEth;
    /// @notice 已锁定、待毕业加池的 ETH
    mapping(address token => uint256) public ethRaisedForLp;
    /// @notice 已预留、毕业时再铸造进池的 meme（按 mint 价折算）
    mapping(address token => uint256) public memeReservedForLp;
    mapping(address token => bool) public graduated;
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
        uint256 ethLockedForLp,
        uint256 memeReserved,
        uint256 ethForCreator
    );
    event MemeBought(address indexed token, address indexed buyer, uint256 ethIn, uint256 memeOut);
    event LiquidityAdded(address indexed token, uint256 amountToken, uint256 amountETH, uint256 liquidity);
    event Graduated(address indexed token, uint256 ethForLp, uint256 memeForLp);
    event FeesClaimed(address indexed account, uint256 amount);

    constructor(address router_) {
        if (router_ == address(0)) revert ZeroRouter();
        router = IUniswapV2Router02(router_);
        WETH = IUniswapV2Router02(router_).WETH();
        uniFactory = IUniswapV2Router02(router_).factory();
        implementation = address(new MemeToken(address(this)));
    }

    receive() external payable {}

    /// @notice 克隆部署 Meme。
    /// @param maxSupply 须能被 `(perMint + 单次预留LP meme)` 整除，且足够 mint 到毕业门槛
    /// @param graduationEth_ 锁定的加池 ETH 累计达到该值后可毕业
    ///
    /// 示例：`deployMeme("DOGE", 1990e18 * 20, 1000e18, 1 ether, 10 ether)`
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
        // perMint 给用户，memeForLp 后续添加流动性
        uint256 mintUnit = perMint + memeForLp;
        if (maxSupply < mintUnit || maxSupply % mintUnit != 0) revert InvalidSupply();

        uint256 ethForLp = price - (price * CREATOR_FEE_BPS) / BPS_DENOMINATOR;
        // 最多 mint 次数 × 每次锁定的 ETH，必须 ≥ 毕业门槛，否则永远筹不够、无法毕业
        if ((maxSupply / mintUnit) * ethForLp < graduationEth_) revert InvalidGraduation();

        token = Clones.clone(implementation);
        isMeme[token] = true;
        graduationEth[token] = graduationEth_;
        MemeToken(token).initialize(msg.sender, symbol, maxSupply, perMint, price);

        emit MemeDeployed(token, msg.sender, symbol, maxSupply, perMint, price, graduationEth_);
    }

    /// @notice 固定价 mint：只铸给买家；99% ETH 锁仓，meme 仅记账预留，不立即加池。
    function mintMeme(address tokenAddr) external payable nonReentrant {
        if (!isMeme[tokenAddr]) revert UnknownMeme();
        if (graduated[tokenAddr]) revert AlreadyGraduated();

        MemeToken token = MemeToken(tokenAddr);
        uint256 price = token.price();
        uint256 perMint = token.perMint();
        if (msg.value != price) revert InvalidPayment();

        uint256 ethForCreator = (msg.value * CREATOR_FEE_BPS) / BPS_DENOMINATOR;
        uint256 ethForLp = msg.value - ethForCreator;
        uint256 memeForLp = (ethForLp * perMint) / price;

        // 已铸造的 meme + 预留的 meme，不能超过 maxSupply（预留的 meme 后续统一铸造并添加流动性）
        uint256 committed = token.totalSupply() + memeReservedForLp[tokenAddr];
        if (token.maxSupply() - committed < perMint + memeForLp) revert InsufficientMintRoom();

        // 铸造 meme 给买家
        token.mint(msg.sender, perMint);

        // 记录锁定的 ETH 和预留的 meme，后续统一铸造并添加流动性
        ethRaisedForLp[tokenAddr] += ethForLp;
        memeReservedForLp[tokenAddr] += memeForLp;
        // 记录 creator 的 creator fee
        pendingFees[token.creator()] += ethForCreator;

        emit MemeMinted(tokenAddr, msg.sender, perMint, msg.value, ethForLp, memeForLp, ethForCreator);

        if (_readyToGraduate(tokenAddr)) {
            uint256 ethLp = ethRaisedForLp[tokenAddr];
            uint256 memeLp = memeReservedForLp[tokenAddr]; // 预留的 meme 数量，还没有铸造
            // 首次建池，min = 全额（按 mint 价配比，无已有储备）
            _graduate(tokenAddr, memeLp, ethLp, memeLp, ethLp, block.timestamp);
        }
    }

    /// @notice 达标后可手动毕业（例如想自定义 deadline/min）；通常最后一笔 mint 已自动毕业。
    function graduate(address tokenAddr, uint256 amountTokenMin, uint256 amountETHMin, uint256 deadline)
        external
        nonReentrant
    {
        if (block.timestamp > deadline) revert Expired();
        if (!isMeme[tokenAddr]) revert UnknownMeme();
        if (graduated[tokenAddr]) revert AlreadyGraduated();
        if (!_readyToGraduate(tokenAddr)) revert GraduationNotReady();

        uint256 ethLp = ethRaisedForLp[tokenAddr];
        uint256 memeLp = memeReservedForLp[tokenAddr];
        _graduate(tokenAddr, memeLp, ethLp, amountTokenMin, amountETHMin, deadline);
    }

    /// @notice 毕业后按 Uniswap 池价买入。
    function buyMeme(address tokenAddr, uint256 amountOutMin, uint256 deadline) external payable nonReentrant {
        if (block.timestamp > deadline) revert Expired();
        if (!isMeme[tokenAddr]) revert UnknownMeme();
        if (!graduated[tokenAddr]) revert NotGraduated();
        if (msg.value == 0) revert ZeroValue();

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenAddr;

        uint256[] memory amounts =
            router.swapExactETHForTokens{value: msg.value}(amountOutMin, path, msg.sender, deadline);

        emit MemeBought(tokenAddr, msg.sender, msg.value, amounts[amounts.length - 1]);
    }

    function claimFees() external nonReentrant {
        uint256 amount = pendingFees[msg.sender];
        if (amount == 0) revert NoFees();
        pendingFees[msg.sender] = 0;
        _sendEth(msg.sender, amount);
        emit FeesClaimed(msg.sender, amount);
    }

    function _memeForLiquidity(uint256 price, uint256 perMint) internal pure returns (uint256) {
        uint256 ethForCreator = (price * CREATOR_FEE_BPS) / BPS_DENOMINATOR;
        // ethForLp: 用于 DEX 的 ETH，返回值: ethForLp ETH 对应的 meme 数量
        uint256 ethForLp = price - ethForCreator;
        return (ethForLp * perMint) / price;
    }

    function _readyToGraduate(address tokenAddr) internal view returns (bool) {
        // 锁定的 ETH 达到毕业门槛
        if (ethRaisedForLp[tokenAddr] >= graduationEth[tokenAddr]) return true;

        // 检查是否支持下一轮 mint，如果不支持下一轮 mint，则立刻毕业
        MemeToken token = MemeToken(tokenAddr);
        uint256 memeForLp = _memeForLiquidity(token.price(), token.perMint());
        uint256 committed = token.totalSupply() + memeReservedForLp[tokenAddr];
        return token.maxSupply() - committed < token.perMint() + memeForLp;
    }

    function _graduate(
        address tokenAddr,
        uint256 memeForLp,
        uint256 ethForLp,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) internal {
        graduated[tokenAddr] = true;
        ethRaisedForLp[tokenAddr] = 0;
        memeReservedForLp[tokenAddr] = 0;

        // 加池前余额含 pendingFees / 捐赠；加池后多出来的是 Router ETH 找零
        uint256 balBefore = address(this).balance - ethForLp;

        MemeToken(tokenAddr).mint(address(this), memeForLp);
        _addLiquidity(tokenAddr, memeForLp, ethForLp, amountTokenMin, amountETHMin, deadline);

        // 首池按 mint 价通常无找零；若有未用完的 ETH，记入 creator 待领（不再退给某次 mint 的人）
        uint256 ethRefund = address(this).balance - balBefore;
        if (ethRefund > 0) {
            pendingFees[MemeToken(tokenAddr).creator()] += ethRefund;
        }

        emit Graduated(tokenAddr, ethForLp, memeForLp);
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

        // 未用完的 meme → DEAD；未用完的 ETH 由 Router 退回本合约，在 _graduate 里记入 pendingFees
        uint256 dustMeme = IERC20(token).balanceOf(address(this));
        if (dustMeme > 0) IERC20(token).transfer(DEAD, dustMeme);

        emit LiquidityAdded(token, usedToken, usedETH, liquidity);
    }

    function _sendEth(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert EthTransferFailed();
    }

    function previewBuy(address tokenAddr, uint256 ethIn) external view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenAddr;
        return router.getAmountsOut(ethIn, path)[1];
    }

    /// @notice 单次 mint 会锁定的 ETH / 预留的 meme
    function previewMintLockAmounts(address tokenAddr)
        external
        view
        returns (uint256 ethLocked, uint256 memeReserved)
    {
        if (!isMeme[tokenAddr]) revert UnknownMeme();
        MemeToken token = MemeToken(tokenAddr);
        uint256 price = token.price();
        ethLocked = price - (price * CREATOR_FEE_BPS) / BPS_DENOMINATOR;
        memeReserved = _memeForLiquidity(price, token.perMint());
    }

    function hasPool(address tokenAddr) external view returns (bool) {
        return IUniswapV2Factory(uniFactory).getPair(tokenAddr, WETH) != address(0);
    }

    function getReserves(address tokenAddr) external view returns (uint256 reserveMeme, uint256 reserveWeth) {
        address pair = IUniswapV2Factory(uniFactory).getPair(tokenAddr, WETH);
        if (pair == address(0)) return (0, 0);
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        return token0 == tokenAddr ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
    }
}
