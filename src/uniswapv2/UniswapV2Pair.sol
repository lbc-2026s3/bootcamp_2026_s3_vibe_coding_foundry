// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import './UniswapV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IUniswapV2Callee.sol';

/// @notice Uniswap V2 交易对：持有两种 ERC20，发 LP（继承 UniswapV2ERC20），提供 mint / burn / swap。
/// @dev 用户通常经 Router 调用；本合约是低层接口，调用方需自行做好安全检查（转币、滑点等）。
///      TWAP 累加器（price0/1CumulativeLast）说明见同目录 `UniswapV2Pair.md`。
contract UniswapV2Pair is UniswapV2ERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    /// @notice 首池永久锁进 address(0) 的最小 LP，防完全抽空池子把价格操纵成任意值。
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;
    address public token1;

    // reserve0 + reserve1 + blockTimestampLast = 112+112+32 = 256 bit，打进同一个 storage slot，省 gas；对外用 getReserves 读。
    uint112 private reserve0;
    uint112 private reserve1;
    uint32  private blockTimestampLast; // 上次更新储备时的 block.timestamp（截断为 uint32）

    /// @notice TWAP 累加器：价格0（token1/token0）随时间积分。详见 `UniswapV2Pair.md`。
    uint public price0CumulativeLast;
    /// @notice TWAP 累加器：价格1（token0/token1）随时间积分。详见 `UniswapV2Pair.md`。
    uint public price1CumulativeLast;
    /// @notice 最近一次加/撤流动性后的 reserve0 * reserve1；协议费开启时用于给 feeTo 铸 LP。
    uint public kLast;

    uint private unlocked = 1;
    /// @notice 简单重入锁：mint / burn / swap / skim / sync 互斥。
    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /// @notice 返回当前储备与上次更新时间戳（三个 private 变量的公开读入口）。
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /// @notice 底层 call 调 ERC20.transfer，兼容不返回 bool 的代币。
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    /// @notice 储备被更新时发出（`_update` 末尾）：同步后的 reserve0 / reserve1，便于链下索引当前池子余额。
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {
        factory = msg.sender; // Factory create2 部署时 msg.sender 即 Factory
    }

    /// @notice Factory 部署后调用一次，写入 token0 / token1（已按地址排序）。
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
    }

    /// @notice 用当前余额更新储备；每个区块首次调用时累加 TWAP 价格累加器。
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32); // 当前时间截成 32 位
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired（uint32 溢出是刻意的）
        }
        // timeElapsed > 0 可以确保同一个区块内只计算一次 TWAP 价格累加器
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            unchecked {
                // 用更新前的储备计算 TWAP 价格累加器
                price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /// @notice 若 Factory.feeTo 非 0，把 sqrt(k) 增长的约 1/6 铸成 LP 给协议费接收地址。
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        // 协议费打开时：在下次 mint/burn 时，把自上次 kLast 以来 k 的增长里 约 1/6 用新 LP 发给 feeTo
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    // 中间有 swap 费把池子 k 抬高了
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    // liquidity = totalSupply * (rootK - rootKLast) / (rootK * 5 + rootKLast)
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            // feeOn = false，把 kLast 清零，协议费关闭（计算协议费时需要 kLast > 0）
            kLast = 0;
        }
    }

    /// @notice 添加流动性：按「当前余额 − 旧储备」算出本次存入量，给 `to` 铸 LP。
    /// @dev 低层函数：须先把 token 转入本 Pair，再调用；通常由 Router 完成安全检查。
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings；须在此缓存，因 _mintFee 可能改 totalSupply
        if (_totalSupply == 0) {
            // 首池：liquidity = sqrt(amount0*amount1) - MINIMUM_LIQUIDITY，并把最小 LP 锁进 address(0)
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            // 后续：按较小比例 mint，保证不稀释另一边
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    /// @notice 移除流动性：销毁本合约持有的 LP，按份额把 token0/token1 转给 `to`。
    /// @dev 低层函数：须先把 LP 转入本 Pair，再调用；通常由 Router 完成。
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings；须在此缓存，因 _mintFee 可能改 totalSupply
        amount0 = liquidity.mul(balance0) / _totalSupply; // 用 balance 按比例分配（含捐赠进池的多余代币）
        amount1 = liquidity.mul(balance1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @notice 兑换：先乐观转出 `amount{0,1}Out`，再校验输入是否足够且恒定乘积 K（含 0.3% 费）成立。
    /// @dev 低层函数；`data.length > 0` 时回调 `to.uniswapV2Call`（闪电贷）。通常由 Router 先转入输入再调 swap。
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        // 由余额反推实际输入（乐观转出后，多出来的余额即对方转入的 amountIn）
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        // 等价于输入抽 0.3%：balanceAdjusted = balance*1000 - amountIn*3，要求乘积 ≥ 旧 k * 1000^2
        uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /// @notice 撇脂：把「余额 − 储备」的多余代币转给 `to`（有人误转/捐赠进池时用）。
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    /// @notice 同步：强制把储备改成当前真实余额（配合 rebase 币等余额变化场景）。
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}
