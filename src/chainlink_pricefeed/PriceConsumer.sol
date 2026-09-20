// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title PriceConsumer — Chainlink Data Feed (ETH/USD) demo
/// @notice 合约不能自己查链下价格：只能读 Chainlink 已经写上链的 Aggregator proxy。
/// @dev 正确读法是 `latestRoundData()`，不要用已弃用的 `latestAnswer()`。
///      新鲜度用 `updatedAt` + heartbeat；不要用已弃用的 `answeredInRound`。
///      始终读 proxy，不要直连底层 aggregator。
///      Data Feed 对外只有一个稳定的 proxy 地址（本合约构造函数注入的就是它）；
///      真正写价格的 aggregator 在 proxy 后面，Chainlink 升级/轮换 aggregator 时
///      只改 proxy 的指向，proxy 地址不变。直连旧 aggregator 会读到停更的过期价。
contract PriceConsumer {
    /// @notice Chainlink 价格源（proxy 地址，构造时注入）。
    AggregatorV3Interface public immutable i_priceFeed;
    /// @notice 允许的最大价格年龄（秒）。超过则视为过期。
    uint256 public immutable i_heartbeat;

    /// @notice `latestRoundData` 的安全读结果。
    struct PriceData {
        /// @notice 本轮报价的 round id。DON 每更新一次价格就递增；可用来区分是不是同一轮数据。
        uint80 roundId;
        /// @notice 1 个 ETH 值多少美元（USD），不是 USDC 代币。
        ///         8 位小数：`2000e8` = 1 ETH = $2000.00000000 USD。
        ///         USDC 只是锚定美元的 ERC-20；本 feed 是 ETH/USD，不是 ETH/USDC。
        ///         本合约在返回前已要求 `answer > 0`。
        int256 answer;
        /// @notice `answer` 的小数位数，运行时从 feed 读取，不写死。ETH/USD 一般为 8。
        uint8 decimals;
        /// @notice 本轮价格写入链上的 Unix 时间戳（秒）。用来和 `i_heartbeat` 比较是否过期。
        uint256 updatedAt;
    }

    error InvalidFeed();
    error InvalidHeartbeat();
    error InvalidPrice(int256 answer);
    error StalePrice(uint256 updatedAt, uint256 heartbeat);

    /// @param feed Chainlink AggregatorV3 proxy（Sepolia ETH/USD 见 README）
    /// @param heartbeat 允许的最大价格年龄（秒）。DON 按时间间隔或价格偏差更新 feed；
    ///                  若 `updatedAt` 距现在超过该值，`getLatestPrice` 会 `StalePrice` revert。
    ///                  必须在 `(0, 7 days]`：0 等于关闭校验，过长则几乎永不拒绝过期价。
    constructor(address feed, uint256 heartbeat) {
        if (feed == address(0)) revert InvalidFeed();
        if (heartbeat == 0 || heartbeat > 7 days) revert InvalidHeartbeat();
        i_priceFeed = AggregatorV3Interface(feed);
        i_heartbeat = heartbeat;
    }

    /// @notice 读取最新 ETH/USD，并校验价格为正、未过期。
    function getLatestPrice() public view returns (PriceData memory price) {
        // latestRoundData() 五个返回值：
        // 1. roundId          本轮报价 id
        // 2. answer           价格（ETH/USD 一般为 8 位小数的 USD）
        // 3. startedAt        本轮开始时间；本 demo 不用（价格是否过期看 updatedAt）
        // 4. updatedAt        本轮价格写入时间；用来和 heartbeat 比新鲜度
        // 5. answeredInRound  答案实际出自哪一轮；官方已弃用，不要拿它做过期判断
        (
            uint80 roundId,
            int256 answer,
            /* uint256 startedAt */,
            uint256 updatedAt,
            /* uint80 answeredInRound */
        ) = i_priceFeed.latestRoundData();

        if (answer <= 0) revert InvalidPrice(answer);
        // updatedAt == 0 表示从未成功 round；未来时间戳视为新鲜（节点时钟偏差）。
        if (updatedAt == 0 || updatedAt + i_heartbeat < block.timestamp) {
            revert StalePrice(updatedAt, i_heartbeat);
        }

        price.roundId = roundId;
        price.answer = answer;
        price.decimals = i_priceFeed.decimals();
        price.updatedAt = updatedAt;
    }

    /// @notice 把 ETH 的 wei 数量换成 USD。返回值使用 feed 的 decimals（ETH/USD 通常为 8）。
    /// @dev `usd = wei * answer / 1e18`。先乘后除，保留 feed 精度。
    ///      例：1 ether、answer = 2000e8 → 2000e8，即 $2000.00000000。
    function getEthValueInUsd(uint256 ethWei) external view returns (uint256 usd, uint8 decimals) {
        PriceData memory price = getLatestPrice();
        usd = (ethWei * uint256(price.answer)) / 1e18;
        decimals = price.decimals;
    }
}
