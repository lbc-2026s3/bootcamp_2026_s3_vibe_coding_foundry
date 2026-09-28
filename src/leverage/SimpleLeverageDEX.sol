// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SimpleLeverageDEX
/// @notice 极简杠杆 DEX：用恒定乘积 vAMM 做多/做空，真实抵押品为 USDC。
/// @dev 教学合约。协议亏损由池内其他用户保证金承担；无保险基金。
contract SimpleLeverageDEX is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public vK;
    uint256 public vETHAmount;
    uint256 public vUSDCAmount;

    IERC20 public immutable USDC;

    uint256 public constant MIN_LEVERAGE = 2;
    uint256 public constant MAX_LEVERAGE = 10;
    /// @notice 亏损超过保证金的该比例时可清算（80%）
    uint256 public constant LIQUIDATION_THRESHOLD_BPS = 8000;
    /// @notice 清算人奖励占保证金比例（5%）
    uint256 public constant LIQUIDATION_REWARD_BPS = 500;
    uint256 public constant BPS = 10_000;

    struct PositionInfo {
        uint256 margin; // 保证金（真实 USDC）
        uint256 borrowed; // 借入的名义 USDC
        int256 position; // 虚拟 ETH 持仓：正=做多，负=做空
    }

    mapping(address => PositionInfo) public positions;

    /// @notice 全市场空头持仓的虚拟 ETH 合计（各空仓 `|PositionInfo.position|` 之和）。
    /// @dev 开空 = 往池子「卖出」vETH（vETH 增加）；平空 = 从池子「买回」同样数量的 vETH（vETH 减少）。
    ///      因此池内必须始终满足 `vETHAmount > totalShortEth`，否则空头买不回、无法平仓。
    ///      做多会消耗 vETH，开多前会检查：成交后的 vETH 仍须大于 `totalShortEth`（给空头预留买回额度）。
    uint256 public totalShortEth;

    event PositionOpened(address indexed user, uint256 margin, uint256 borrowed, int256 position, bool long);
    event PositionClosed(address indexed user, int256 pnl, uint256 payout);
    event PositionLiquidated(
        address indexed user, address indexed liquidator, int256 pnl, uint256 userPayout, uint256 reward
    );

    constructor(uint256 vEth, uint256 vUSDC, address usdc_) {
        require(vEth > 0 && vUSDC > 0, "invalid reserves");
        require(usdc_ != address(0), "zero usdc");
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;
        USDC = IERC20(usdc_);
    }

    /// @notice 精确输入交换（exact-in）：指定「投入」一侧数量，按 `x * y = k` 算出另一侧产出，并更新虚拟储备。
    /// exact-in：定投入，算产出；返回值表示另一侧得到多少
    /// @dev 必须且只能一侧输入为 0、另一侧 > 0。无手续费；整数除法会使 `vETH * vUSDC` 略偏离 `vK`。
    /// @param inputvEth 投入的虚拟 ETH；卖 ETH 换 USDC 时填此值，否则为 0
    /// @param inputvUSDC 投入的虚拟 USDC；买 ETH（付 USDC）时填此值，否则为 0
    /// @return output 另一侧得到的数量：投入 ETH 则返回得到的 USDC；投入 USDC 则返回得到的 ETH
    function vAmmSwapByInput(uint256 inputvEth, uint256 inputvUSDC) internal returns (uint256 output) {
        if (inputvEth > 0 && inputvUSDC == 0) {
            // 卖 ETH → 池内 vETH↑、vUSDC↓，产出为减少的 USDC
            vETHAmount += inputvEth;
            uint256 vUSDCAmountLast = vUSDCAmount;
            vUSDCAmount = vK / vETHAmount;
            require(vUSDCAmountLast > vUSDCAmount, "zero out");
            output = vUSDCAmountLast - vUSDCAmount;
        } else if (inputvEth == 0 && inputvUSDC > 0) {
            // 付 USDC 买 ETH → 池内 vUSDC↑、vETH↓，产出为减少的 ETH
            vUSDCAmount += inputvUSDC;
            uint256 vEthAmountLast = vETHAmount;
            vETHAmount = vK / vUSDCAmount;
            require(vEthAmountLast > vETHAmount, "zero out");
            output = vEthAmountLast - vETHAmount;
        } else {
            revert("invalid input");
        }
    }

    /// @notice 精确输出交换（exact-out）：指定要从池中「取出」一侧数量，按 `x * y = k` 算出另一侧需投入多少，并更新虚拟储备。
    /// exact-out：定取出，算投入；返回值表示另一侧要付/卖多少
    /// @dev 必须且只能一侧输出为 0、另一侧 > 0。取出量必须严格小于该侧当前储备，否则会抽干池子。
    /// @param outputvEth 要从池中取出的虚拟 ETH；买回 ETH（平空）时填此值，否则为 0
    /// @param outputvUSDC 要从池中取出的虚拟 USDC；开空「卖 ETH 换出 USDC」时填此值，否则为 0
    /// @return input 另一侧需要投入/增加的数量：取出 ETH 则返回需支付的 USDC；取出 USDC 则返回需卖出的 ETH
    function vAmmSwapByOutput(uint256 outputvEth, uint256 outputvUSDC) internal returns (uint256 input) {
        if (outputvEth > 0 && outputvUSDC == 0) {
            // 从池中取走 ETH → vETH↓、vUSDC↑，投入为增加的 USDC（买 ETH 成本）
            require(outputvEth < vETHAmount, "insufficient vETH");
            vETHAmount -= outputvEth;
            uint256 vUSDCAmountLast = vUSDCAmount;
            vUSDCAmount = vK / vETHAmount;
            require(vUSDCAmount > vUSDCAmountLast, "zero in");
            return vUSDCAmount - vUSDCAmountLast;
        } else if (outputvEth == 0 && outputvUSDC > 0) {
            // 从池中取走 USDC → vUSDC↓、vETH↑，投入为增加的 ETH（卖 ETH 数量）
            require(outputvUSDC < vUSDCAmount, "insufficient vUSDC");
            vUSDCAmount -= outputvUSDC;
            uint256 vEthAmountLast = vETHAmount;
            vETHAmount = vK / vUSDCAmount;
            require(vETHAmount > vEthAmountLast, "zero in");
            return vETHAmount - vEthAmountLast;
        } else {
            revert("invalid output");
        }
    }

    /// @notice 用 USDC 保证金开仓：名义仓位 = `_margin * level`，借入 `_margin * (level - 1)`。
    /// @param _margin 保证金（真实 USDC，需事先 approve）
    /// @param level 杠杆倍数，范围 `[MIN_LEVERAGE, MAX_LEVERAGE]`；如 `5` 表示 5x
    /// @param long `true` 做多（买入 vETH），`false` 做空（卖出 vETH）
    function openPosition(uint256 _margin, uint256 level, bool long) external nonReentrant {
        require(positions[msg.sender].position == 0, "Position already open");
        require(_margin > 0, "zero margin");
        require(level >= MIN_LEVERAGE && level <= MAX_LEVERAGE, "invalid leverage");

        PositionInfo storage pos = positions[msg.sender];
        uint256 amount = _margin * level;
        uint256 borrowAmount = amount - _margin;

        if (long) {
            // 额外检查：做多会减少 vETH；若减到 <= 空头合计，已有空仓将无法买回平仓，需要给空头留够「买回额度」
            uint256 newUsdc = vUSDCAmount + amount;
            uint256 newEth = vK / newUsdc;
            // 不可以 >=，必须 newEth > totalShortEth，平仓的时候不能抽干池子
            require(newEth > totalShortEth, "insufficient liquidity");
        }

        USDC.safeTransferFrom(msg.sender, address(this), _margin);

        pos.margin = _margin;
        pos.borrowed = borrowAmount;

        if (long) {
            // 用名义 USDC 买入虚拟 ETH
            pos.position = int256(vAmmSwapByInput(0, amount));
        } else {
            // 卖出虚拟 ETH，换出名义 USDC（价格被压低）
            uint256 ethSize = vAmmSwapByOutput(0, amount);
            pos.position = -int256(ethSize);
            // 记录空头合计
            totalShortEth += ethSize;
        }

        emit PositionOpened(msg.sender, _margin, borrowAmount, pos.position, long);
    }

    /// @notice 关闭自己的头寸并结算。亏损超过保证金时只拿回 0（剩余归池）。
    function closePosition() external nonReentrant {
        PositionInfo memory position = positions[msg.sender];
        require(position.position != 0, "No open position");

        // PnL = Profit and Loss（盈亏），正数是盈利，负数是亏损，单位是 USDC
        int256 pnl = calculatePnL(msg.sender);

        // 在 vAMM 上反向成交，把仓位平掉（返回值不参与结算，盈亏已由上面的 pnl 算好）
        if (position.position > 0) {
            // 平多：卖出持仓 vETH，换回虚拟 USDC
            vAmmSwapByInput(uint256(position.position), 0);
        } else {
            // 平空：买回开空时卖出的 vETH，释放预留额度
            uint256 ethSize = uint256(-position.position);
            vAmmSwapByOutput(ethSize, 0);
            totalShortEth -= ethSize;
        }

        uint256 payout = _equityAfterPnl(position.margin, pnl);

        delete positions[msg.sender];
        if (payout > 0) {
            USDC.safeTransfer(msg.sender, payout);
        }

        emit PositionClosed(msg.sender, pnl, payout);
    }

    /// @notice 清算他人头寸：先在 vAMM 平仓，再按净值分配清算奖励与用户退款。
    /// @dev 触发条件：未实现亏损严格大于保证金的 `LIQUIDATION_THRESHOLD_BPS`（默认 80%）。
    ///      清算人奖励为保证金的 `LIQUIDATION_REWARD_BPS`（默认 5%），但不超过当前净值；穿仓时奖励可为 0。
    /// @param _user 被清算地址；不能是 `msg.sender`
    function liquidatePosition(address _user) external nonReentrant {
        require(msg.sender != _user, "Cannot liquidate own position");

        PositionInfo memory position = positions[_user];
        require(position.position != 0, "No open position");

        int256 pnl = calculatePnL(_user);
        // 亏损须超过保证金 × 80%，才允许清算
        require(
            pnl < -int256(position.margin * LIQUIDATION_THRESHOLD_BPS / BPS), "Position not liquidatable"
        );

        // 与 closePosition 相同：在 vAMM 反向成交，平掉仓位
        if (position.position > 0) {
            // 平多：卖出持仓 vETH
            vAmmSwapByInput(uint256(position.position), 0);
        } else {
            // 平空：买回 vETH，释放预留额度
            uint256 ethSize = uint256(-position.position);
            vAmmSwapByOutput(ethSize, 0);
            totalShortEth -= ethSize;
        }

        // 净值 = 保证金 ± 盈亏（亏损超过保证金则为 0）
        uint256 equity = _equityAfterPnl(position.margin, pnl);
        // 清算奖励：保证金的 5%，但不得超过净值（避免从池子多掏）
        uint256 reward = position.margin * LIQUIDATION_REWARD_BPS / BPS;
        if (reward > equity) {
            reward = equity;
        }
        uint256 userPayout = equity - reward;

        delete positions[_user];

        if (userPayout > 0) {
            USDC.safeTransfer(_user, userPayout);
        }
        if (reward > 0) {
            USDC.safeTransfer(msg.sender, reward);
        }

        emit PositionLiquidated(_user, msg.sender, pnl, userPayout, reward);
    }

    /// @notice 相对开仓名义的未实现盈亏（USDC）。
    /// @dev 多仓：平仓可得 USDC - 开仓名义；空仓：开仓名义 - 平仓所需 USDC。
    function calculatePnL(address user) public view returns (int256) {
        PositionInfo memory position = positions[user];
        if (position.position == 0) return 0;

        uint256 notional = position.borrowed + position.margin;

        if (position.position > 0) {
            // 卖出持仓 ETH 可得的 USDC
            uint256 usdcAfter = vK / (vETHAmount + uint256(position.position));
            uint256 proceeds = vUSDCAmount - usdcAfter;
            // 盈亏 = 卖出所得 - 名义仓位（借入的 USDC + 保证金，即开仓成本）
            return int256(proceeds) - int256(notional);
        } else {
            // 买回空仓 ETH 所需的 USDC
            uint256 ethSize = uint256(-position.position);
            require(ethSize < vETHAmount, "position too large");
            uint256 usdcAfter = vK / (vETHAmount - ethSize);
            uint256 cost = usdcAfter - vUSDCAmount;
            // 盈亏 = 名义仓位（借入的 USDC + 保证金，即开仓成本） - 买入所需 USDC
            return int256(notional) - int256(cost);
        }
    }

    function _equityAfterPnl(uint256 margin, int256 pnl) internal pure returns (uint256) {
        if (pnl >= 0) {
            return margin + uint256(pnl);
        }
        uint256 loss = uint256(-pnl);
        if (loss >= margin) {
            return 0;
        }
        return margin - loss;
    }
}
