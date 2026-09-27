// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Compound Jump Rate：拐点以下一条斜率，拐点以上更陡。
/// 利率是每秒 wad。wad 不是缩写，来自 MakerDAO 的定点数：固定 18 位小数，1e18 表示 1.0，在利率里就是 100%。
contract JumpRateModel {
    uint256 internal constant WAD = 1e18;

    uint256 public immutable baseRatePerSecond;
    uint256 public immutable multiplierPerSecond;
    uint256 public immutable jumpMultiplierPerSecond;
    uint256 public immutable kink;

    error InvalidKink();

    constructor(
        uint256 baseRatePerSecond_,
        uint256 multiplierPerSecond_,
        uint256 jumpMultiplierPerSecond_,
        uint256 kink_
    ) {
        if (kink_ == 0 || kink_ > WAD) revert InvalidKink();
        baseRatePerSecond = baseRatePerSecond_;
        multiplierPerSecond = multiplierPerSecond_;
        jumpMultiplierPerSecond = jumpMultiplierPerSecond_;
        kink = kink_;
    }

    /// @notice 借款占「现金 + 借款 - 储备金」的比例，1e18 表示 100%。
    function utilizationRate(uint256 cash, uint256 borrows, uint256 reserves) public pure returns (uint256) {
        if (borrows == 0) return 0;
        uint256 denom = cash + borrows - reserves;
        if (denom == 0) return 0;
        return borrows * WAD / denom;
    }

    /// @notice 每秒借款利率，1e18 刻度。
    function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) public view returns (uint256) {
        uint256 util = utilizationRate(cash, borrows, reserves);
        if (util <= kink) {
            return baseRatePerSecond + util * multiplierPerSecond / WAD;
        }
        uint256 normalRate = baseRatePerSecond + kink * multiplierPerSecond / WAD;
        return normalRate + (util - kink) * jumpMultiplierPerSecond / WAD;
    }

    /// @notice 展示用存款利率。池子不存储它，存款人靠汇率上涨获得利息。
    /// 存款利率 = 借款利率 × 利用率 × (1 - 储备金比例)。返回值仍是每秒 wad，1e18 = 100%。
    function getSupplyRate(uint256 cash, uint256 borrows, uint256 reserves, uint256 reserveFactor)
        public
        view
        returns (uint256)
    {
        uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
        uint256 util = utilizationRate(cash, borrows, reserves);
        // 只有借出去的资金在产生利息，所以先乘利用率。
        // 利息里储备金比例那一份归协议，存款人只拿剩下的 (1 - reserveFactor)。
        // 利用率和储备金比例都是 wad，每乘一次两个 wad 就要 / WAD，把刻度缩回 18 位小数。
        // 例：借款年化 10%、利用率 80%、储备金 10% 时，存款年化 = 10% × 80% × 90% = 7.2%。
        return borrowRate * util / WAD * (WAD - reserveFactor) / WAD;
    }
}
