// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {PriceConsumer} from "../../src/chainlink_pricefeed/PriceConsumer.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceConsumerTest is Test {
    uint8 internal constant DECIMALS = 8;
    int256 internal constant ETH_USD_2000 = 2000e8;
    uint256 internal constant HEARTBEAT = 1 hours;

    MockV3Aggregator internal feed;
    PriceConsumer internal consumer;

    function setUp() public {
        feed = new MockV3Aggregator(DECIMALS, ETH_USD_2000);
        consumer = new PriceConsumer(address(feed), HEARTBEAT);
    }

    function test_getLatestPriceReturnsAnswerDecimalsAndUpdatedAt() public view {
        PriceConsumer.PriceData memory price = consumer.getLatestPrice();

        assertEq(price.answer, ETH_USD_2000);
        assertEq(price.decimals, DECIMALS);
        assertEq(price.updatedAt, block.timestamp);
        assertGt(uint256(price.roundId), 0);
    }

    function test_oneEtherEqualsFeedAnswer() public view {
        (uint256 usd, uint8 decimals) = consumer.getEthValueInUsd(1 ether);

        assertEq(usd, uint256(ETH_USD_2000));
        assertEq(decimals, DECIMALS);
    }

    function test_halfEtherIsHalfUsd() public view {
        (uint256 usd,) = consumer.getEthValueInUsd(0.5 ether);
        assertEq(usd, uint256(ETH_USD_2000) / 2);
    }

    function test_zeroWeiReturnsZeroUsd() public view {
        (uint256 usd,) = consumer.getEthValueInUsd(0);
        assertEq(usd, 0);
    }

    function testFuzz_EthValueScalesLinearly(uint256 ethWei) public view {
        ethWei = bound(ethWei, 0, 1e27); // 最多 1e9 ETH，避免 overflow
        (uint256 usd,) = consumer.getEthValueInUsd(ethWei);
        assertEq(usd, (ethWei * uint256(ETH_USD_2000)) / 1e18);
    }

    function test_RevertWhen_PriceIsZero() public {
        feed.updateAnswer(0);
        vm.expectRevert(abi.encodeWithSelector(PriceConsumer.InvalidPrice.selector, int256(0)));
        consumer.getLatestPrice();
    }

    function test_RevertWhen_PriceIsNegative() public {
        feed.updateAnswer(-1);
        vm.expectRevert(abi.encodeWithSelector(PriceConsumer.InvalidPrice.selector, int256(-1)));
        consumer.getLatestPrice();
    }

    function test_RevertWhen_PriceIsStale() public {
        uint256 updatedAt = block.timestamp;
        vm.warp(updatedAt + HEARTBEAT + 1);

        vm.expectRevert(abi.encodeWithSelector(PriceConsumer.StalePrice.selector, updatedAt, HEARTBEAT));
        consumer.getLatestPrice();
    }

    function test_RevertWhen_UpdatedAtIsZero() public {
        feed.updateRoundData(1, ETH_USD_2000, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(PriceConsumer.StalePrice.selector, uint256(0), HEARTBEAT));
        consumer.getLatestPrice();
    }

    function test_priceExactlyAtHeartbeatIsAccepted() public {
        uint256 updatedAt = block.timestamp;
        vm.warp(updatedAt + HEARTBEAT);
        PriceConsumer.PriceData memory price = consumer.getLatestPrice();
        assertEq(price.updatedAt, updatedAt);
    }

    function test_RevertWhen_FeedIsZero() public {
        vm.expectRevert(PriceConsumer.InvalidFeed.selector);
        new PriceConsumer(address(0), HEARTBEAT);
    }

    function test_RevertWhen_HeartbeatIsZero() public {
        vm.expectRevert(PriceConsumer.InvalidHeartbeat.selector);
        new PriceConsumer(address(feed), 0);
    }

    function test_RevertWhen_HeartbeatTooLong() public {
        vm.expectRevert(PriceConsumer.InvalidHeartbeat.selector);
        new PriceConsumer(address(feed), 7 days + 1);
    }
}

contract PriceConsumerMainnetForkTest is Test {
    // ethskills.com/addresses — Mainnet ETH/USD, verified March 2026
    address internal constant MAINNET_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    uint256 internal constant FORK_BLOCK = 25_925_858;
    uint256 internal constant HEARTBEAT = 3 hours;

    PriceConsumer internal consumer;

    function setUp() public {
        try vm.createSelectFork("mainnet", FORK_BLOCK) {}
        catch {
            vm.skip(true);
            return;
        }

        if (MAINNET_ETH_USD.code.length == 0) {
            vm.skip(true);
            return;
        }

        consumer = new PriceConsumer(MAINNET_ETH_USD, HEARTBEAT);
    }

    function test_MainnetFeed_LiveEthUsd() public view {
        PriceConsumer.PriceData memory price = consumer.getLatestPrice();

        assertGt(price.answer, 0);
        assertEq(price.decimals, 8);
        assertGt(price.updatedAt, 0);
        assertLe(block.timestamp - price.updatedAt, HEARTBEAT);

        (uint256 usd, uint8 decimals) = consumer.getEthValueInUsd(1 ether);
        assertEq(usd, uint256(price.answer));
        assertEq(decimals, 8);
        // sanity：$100 .. $100,000（8 decimals）
        assertGe(usd, 100e8);
        assertLe(usd, 100_000e8);

        string memory desc = AggregatorV3Interface(MAINNET_ETH_USD).description();
        assertEq(desc, "ETH / USD");
    }
}
