# 2026 年的 gas 工具：报告、优化器、逐步剖析

这三个名字还在用，但 2026 年没有三件必须另装的软件。

本仓库是 Foundry（`forge 1.8.1`，Solidity `0.8.34`，`evm_version = osaka`）。函数级报告是 `forge test --gas-report`，优化器是 `solc` 自带的，逐步剖析是 `forge test -vvvv` 的调用树，外加单测用的 `--flamegraph`。Hardhat 2 项目里的 `hardhat-gas-reporter` 仍然有人装；Hardhat 3 自己有 snapshot。Truffle 时代的 `eth-gas-reporter` 在 2024 年 3 月归档。

下面的数字都是 2026-10-28 在本仓库跑出来的，配置是 default profile：`optimizer = false`，`optimizer_runs = 200`（优化器关着时这个数不生效），`via_ir = false`。

## 先看这次测量

`test/library_demo/LibraryLink.t.sol` 调了两个计算器。`InlineCalculator.calculate` 把 `internal` 库函数嵌进自己的字节码。`LinkedCalculator.calculate` 对已部署的 `LinkedMath` 做 `DELEGATECALL`。源码都是 `a.add(b)`。

优化器关闭时，函数报告是：

| 合约 | 函数 | gas | 调用次数 |
| --- | --- | ---: | ---: |
| `InlineCalculator` | `calculate` | 1010 | 1 |
| `InlineCalculator` | `increment` | 43568 | 1 |
| `LinkedCalculator` | `calculate` | 4958 | 1 |
| `LinkedCalculator` | `increment` | 46909 | 1 |
| `LinkedMath` | `add` | 954 | 2 |
| `LinkedMath` | `readSlot0` | 2393 | 1 |

`calculate` 两边差 3948。`increment` 两边差 3341。两次差额接近：多出来的是那一次 `DELEGATECALL`。`increment` 本身落在「第一次把 0 槽写成非 0」的量级上，协议里这项是 20000 gas，再加上冷访问和外部调用的开销，所以绝对值在 4 万多。

打开优化器再跑同一组测试（`--optimize true`，`runs` 取 1 和 200 各一次），函数 gas 变成：

| 函数 | 优化器关 | 优化器开（runs = 1 和 200 相同） |
| --- | ---: | ---: |
| `InlineCalculator.calculate` | 1010 | 427 |
| `InlineCalculator.increment` | 43568 | 43444 |
| `LinkedCalculator.calculate` | 4958 | 3547 |
| `LinkedCalculator.increment` | 46909 | 46489 |

纯计算从 1010 降到 427。写存储的 `increment` 只少了 124。这两个合约太小，`optimizer_runs` 从 1 改到 200，函数 gas 没有变化。体积上的差别见后面的字节码表：`PackedSlot` 才会随着 runs 变长。

同一时刻，测试括号里的 gas 完全是另一件事：

```text
test_inline_add_has_no_delegatecall()           617754
test_inline_increment_updates_own_storage()      51911
test_linked_add_delegatecalls_library()         846573
test_linked_write_hits_caller_storage()         894117
```

`test_inline_add` 的 617754 里，`calculate` 只占 1010。其余是测试在字节码里逐字节找 `DELEGATECALL`（opcode `0xf4`）。优化器把字节码缩短之后，这个测试降到 205137，函数本身只降到 427。拿测试括号里的数字去比较 `add` 的实现，会把扫描循环当成业务逻辑。

## 名字对应到哪一件工具

| 口头说法 | 2026 年实际用的 | 本仓库 |
| --- | --- | --- |
| Gas Reporter | Foundry：`forge test --gas-report`。Hardhat 2：`hardhat-gas-reporter`（npm `2.3.0`，2025-06-01 发布；查阅当日页面上的周下载量大约 11 万）。Hardhat 3：测试自带 `--snapshot`、`--snapshot-check`、`--gas-stats-json` | 用 Foundry 那条 |
| Solidity Optimizer | `solc` 的优化器，由 `optimizer`、`optimizer_runs`、`via_ir` 打开。它是编译器的一部分 | default 关闭；`[profile.deploy]` 打开，并且 `optimizer_runs = 1` |
| Gas Profiler | 单笔执行的调用树和 opcode 成本。Foundry 用 `-vvvv`、`--flamegraph`、`--flamechart`、`--evm-profile`。Remix 调试器按步显示剩余 gas。Tenderly 看已上链交易 | 用 `-vvvv` 读 `PackedSlot` 的创建 |

`eth-gas-reporter` 是更早的 Mocha reporter，仓库已于 2024 年 3 月归档，新项目不必装。

## Foundry gas report

### 安装

gas report 跟着 `forge` 走，没有单独的包。本机已经是：

```text
forge Version: 1.8.1
Commit SHA: 982849d3140c01fd3b72905759581a132df7aa98
Build Timestamp: 2026-08-28
```

新环境按 [Foundry 安装说明](https://getfoundry.sh/introduction/installation/) 装 `foundryup`，再 `foundryup`。版本用 `forge --version` 看。

### 使用

只跑库演示，避免整库测试把无关合约刷进表里：

```bash
forge test --match-path test/library_demo/LibraryLink.t.sol --gas-report
```

存储演示：

```bash
forge test --match-path test/storage/PackedSlot.t.sol --gas-report
```

`foundry.toml` 没有写 `gas_reports`。`forge config` 里的生效值是 `["*"]`，也就是全收。要固定收哪些合约，写进 default profile：

```toml
gas_reports = ["InlineCalculator", "LinkedCalculator", "LinkedMath"]
gas_reports_ignore = ["Script"]
```

`gas_reports` 里点名的合约，即使同时出现在 ignore 里，也会出报告。

比较优化器时用命令行覆盖，改完用一次不带这些旗标的 `forge build` 回到 `foundry.toml`。这次覆盖会重编大约 295 个文件，本机大约 40 秒，并写进 `out/`：

```bash
forge test --match-path test/library_demo/LibraryLink.t.sol --gas-report --optimize true --optimizer-runs 200
forge build
```

`--isolate` 会把每个顶层调用放进独立交易里再记账。这次库测试加上它，三张表的数字没有变化。

### 报告长什么样

优化器关闭时，`InlineCalculator` 这一段是：

```text
| Deployment Cost                                                 | Deployment Size |
|                                                               0 |             582 |
| Function Name                                                   | Min  | Avg   | Median | Max   | # Calls |
| calculate                                                       | 1010 | 1010  | 1010   | 1010  |       1 |
| counter                                                         | 2402 | 2402  | 2402   | 2402  |       1 |
| increment                                                       | 43568| 43568 | 43568  | 43568 |       1 |
```

`LinkedMath` 是少数 Deployment Cost 有数的一张：

```text
| Deployment Cost | Deployment Size |
|          116188 |             657 |
| add             | Min 954 | Avg 954 | Median 954 | Max 954 | # Calls 2 |
| readSlot0       | Min 2393| ...                                     | # Calls 1 |
```

列的含义：

| 列 | 这次测量里它是什么 |
| --- | --- |
| Min / Avg / Median / Max | 该外部函数在这次测试里每次调用的 gas。只有 1 次调用时四列相同。Min 和 Max 拉开，说明冷热存储、分支或参数长度走了不同路径 |
| # Calls | 测试实际打到这个函数的次数。没被调用的函数不会出现 |
| Deployment Size | 和 `forge inspect <合约> bytecode` 的字节数对齐，也就是带 metadata 的创建字节码。`InlineCalculator` 两边都是 582，`LinkedCalculator` 882，`LinkedMath` 657。`PackedSlot` 的报告是 1159，inspect 的创建字节码是 1063；多出来的 96 字节是三个构造参数的 ABI 编码（3 × 32） |
| Deployment Cost | 报告收集到的一次部署所花的 gas。收集不到时这里是 0，Size 仍然有数 |

`LinkedMath` 的 116188 可以拆开核对。带 metadata 的运行时字节码是 580 字节，代码存储按 200 gas/字节计是 116000，剩下 188 是库构造执行。这个库的构造函数不写存储，所以两项加起来刚好是报告里的部署成本。

另外两个计算器的 Deployment Cost 是 0，因为它们在 `setUp()` 里 `new`。`setUp` 不进这张表的部署成本，Size 仍从产物里读出来。

`PackedSlot` 更隐蔽。测试函数里的 `new PackedSlot(X, Y, Z)` 在 forge 1.8.1 上变成 cheatcode `VM::deployCode`。父调用的 gas 显示是 0，于是报告里的 Deployment Cost 也是 0。`-vvvv` 的子调用才是真实创建成本：

```text
[18337] PackedSlotTest::test_unpack_three_variables_from_one_slot()
  ├─ [0] VM::deployCode("src/storage/PackedSlot.sol:PackedSlot", ...)
  │   ├─ [152436] → new PackedSlot@0x5615...
  │   └─ ← [Return]
  ├─ [2475] PackedSlot::raw() [staticcall]
  ├─ [2703] PackedSlot::unpack() [staticcall]
```

所以这一个测试里有三个不同的数：

| 数字 | 出处 | 代表什么 |
| ---: | --- | --- |
| 18337 | 测试通过行括号里的 gas | 父调用。`deployCode` 对父调用记 0，剩下的是 `raw`、`unpack` 和测试自己的断言 |
| 0 | gas report 的 Deployment Cost | 同一原因，创建没记进报告 |
| 152436 | trace 里的 `new PackedSlot` | 这次创建实际烧掉的 gas |
| 2475 / 2703 | gas report 的 `raw` / `unpack` | 和 trace 里那两行一一对应 |

同一套测试里，不带构造参数的 `new OptimizedLayout()` 走普通 `CREATE`，报告给出了 Deployment Cost **280387**、Size **1153**。读 Deployment Cost 之前先看它是不是 0；是 0 就打开 `-vvvv` 找 `→ new`。

编译器自己的估算用：

```bash
forge inspect src/library_demo/InlineCalculator.sol:InlineCalculator gasEstimates
```

优化器关闭时，`InlineCalculator` 的结果是：

```json
{
  "creation": {
    "codeDepositCost": "110800",
    "executionCost": "157",
    "totalCost": "110957"
  },
  "external": {
    "calculate(uint256,uint256)": "infinite",
    "counter()": "2402",
    "increment()": "infinite"
  }
}
```

`110800 / 200 = 554`，等于带 metadata 的运行时字节码长度。`counter()` 的 2402 和 gas report 一致，因为这个 getter 的存储读取对编译器是确定的。`calculate` 和 `increment` 标成 `infinite`：编译器拒绝给依赖调用数据或存储的函数一个单一数字。这种函数以 gas report 和 trace 为准。

`view` / `pure` 的测量是这次调用路径的消耗。链上从冷账户、冷槽位再调一次，会更高。`hardhat-gas-reporter` 的文档对这一点有同样的说明。

## Solidity 优化器

优化器不用安装。`solc` 在编译时跑，Foundry 用配置或旗标打开。官方说明在 [The Optimizer](https://docs.soliditylang.org/en/latest/internals/optimizer.html)。

`optimizer_runs` 的意思是：部署之后，部署字节码里的每个 opcode 大概会被执行多少次。它是部署成本（代码短）和运行成本（代码长、调用更便宜）之间的旋钮。它不是优化器的循环次数；能简化的地方，优化器都会做完。

| runs | 编译器的取向 |
| ---: | --- |
| 1 | 字节码短，适合部署一次、之后很少调用，也适合卡 EIP-170 的 24576 字节上限 |
| 200 | 常用的中间值 |
| 很大，例如 10000 以上 | 调用非常频繁的核心合约，允许字节码变长 |

本仓库的 `foundry.toml`：

```26:32:foundry.toml
# 本地 anvil 部署用：开 optimizer + 去掉 metadata，压体积避免 Router 超 EIP-170 / anvil 日志爆炸
[profile.deploy]
optimizer = true
optimizer_runs = 1
bytecode_hash = "none"
cbor_metadata = false
```

default profile 把 `via_ir` 关掉，注释写的原因是 `solc 0.8.34 + via_ir` 会在编译 `script/` 时遇到 Yul stack-too-deep。部署用：

```bash
FOUNDRY_PROFILE=deploy forge build
```

### 字节码体积（这次量的）

下面是 `forge inspect <合约> bytecode|deployedBytecode --no-metadata` 的字节数。去掉 metadata，是为了不让每份产物末尾那段 CBOR 把差值淹没。gas report 的 Deployment Size 含 metadata，所以和这张表对不上，那是预期的。

| 合约 | 字段 | 优化器关 | runs = 1 | runs = 200 | via IR，runs = 200 |
| --- | --- | ---: | ---: | ---: | ---: |
| `InlineCalculator` | 创建 / 运行时 | 528 / 500 | 246 / 220 | 246 / 220 | 198 / 174 |
| `LinkedCalculator` | 创建 / 运行时 | 828 / 800 | 484 / 456 | 484 / 456 | 466 / 440 |
| `LinkedMath` | 创建 / 运行时 | 603 / 526 | 285 / 234 | 285 / 234 | 222 / 191 |
| `PackedSlot` | 创建 / 运行时 | 1009 / 590 | 505 / 272 | 514 / 281 | 500 / 288 |

打开优化器，这几个合约的创建字节码大约砍掉一半。`InlineCalculator` 的 runs = 1 和 runs = 200 体积相同，函数 gas 也相同。`PackedSlot` 从 runs = 1 到 200，创建字节码 505 → 514，运行时 272 → 281，方向是「runs 变大，代码变长」。这次没有再测它的运行时 gas，所以这里只记录体积。

`via_ir` 让 `InlineCalculator` 的创建字节码再从 246 降到 198。它编译更慢，而且本仓库全量编译 `script/` 时会 stack-too-deep。对单个合约做体积对比可以用：

```bash
forge inspect src/library_demo/InlineCalculator.sol:InlineCalculator bytecode --optimize true --optimizer-runs 200 --via-ir --no-metadata
```

全量 `forge build` 继续用 `foundry.toml` 里的 `via_ir = false`。

## 逐步剖析：trace、snapshot、flamegraph

### trace

函数报告把一次调用收成一个数。要看这个数里面是创建、外部调用还是测试自己的循环，加 `-vvvv`：

```bash
forge test --match-test test_unpack_three_variables_from_one_slot -vvvv
```

上面的 `152436 / 2475 / 2703` 就是这样读出来的。trace 里的方括号是该帧消耗的 gas，已经包含子调用。父帧和子帧不要相加。

### snapshot

snapshot 记录的是每个测试函数的 gas，和通过行括号里的数字是同一个。它适合拦住回退，不适合单独解释某个业务函数。

```bash
forge snapshot --match-path test/library_demo/LibraryLink.t.sol --snap /tmp/library.gas-snapshot
forge snapshot --match-path test/library_demo/LibraryLink.t.sol --diff /tmp/library.gas-snapshot
forge snapshot --check /tmp/library.gas-snapshot
```

这次写出来的文件是：

```text
LibraryLinkTest:test_inline_add_has_no_delegatecall() (gas: 617754)
LibraryLinkTest:test_inline_increment_updates_own_storage() (gas: 51911)
LibraryLinkTest:test_linked_add_delegatecalls_library() (gas: 846573)
LibraryLinkTest:test_linked_write_hits_caller_storage() (gas: 894117)
```

`--check` 在和文件不一致时返回非 0。fuzz 测试会写成 `runs`、均值 `μ`、中位数 `~`。容差用 `--tolerance <百分比>`。

CI 里可以：

```yaml
- name: Check gas
  run: forge snapshot --check
```

故意改了 gas 之后，重新 `forge snapshot`，再把 `.gas-snapshot` 和代码一起提交。本仓库还没有这份文件。`test_inline_add` 这类会扫描整段字节码的测试，优化器或无关的代码尺寸变化也会让 snapshot 失败，排查时回到 `--gas-report` 看函数行。

更细的分段在测试里用 cheatcode（这次的演示测试没有用它们）：

```solidity
vm.pauseGasMetering();
_setup();
vm.resumeGasMetering();

vm.startSnapshotGas("increment");
counter.increment();
uint256 used = vm.stopSnapshotGas();
```

`gasleft()` 的差值也能量一段。在 Osaka 上这就是普通 gas。Amsterdam 的状态 gas 不在 `gasleft()` 里，见文末。

### flamegraph

一张图只对一个测试。`--no-open` 只落盘，不打开浏览器：

```bash
forge test --match-test test_inline_increment_updates_own_storage --flamegraph --no-open
forge test --match-test test_inline_increment_updates_own_storage --flamechart --no-open
forge test --match-test test_inline_increment_updates_own_storage --evm-profile speedscope --no-open
```

`--flamegraph` 按累计 gas 看谁最贵。`--flamechart` 按调用顺序看。`--evm-profile` 写成 [speedscope](https://www.speedscope.app/) 的格式。这三个旗标都会打开内部函数解码。

## 存储布局

优化器动的是字节码。槽位怎么排，要改源码，工具负责把排法印出来。

```bash
forge inspect src/storage/PackedSlot.sol:PackedSlot storageLayout
```

```text
| Name | Type    | Slot | Offset | Bytes |
| x    | uint64  | 0    | 0      | 8     |
| y    | uint64  | 0    | 8      | 8     |
| z    | uint128 | 0    | 16     | 16    |
```

三个变量共用 slot 0。测试 `test_unpack_three_variables_from_one_slot` 读出的字是：

```text
0x0000000000000000000000000000333300000000000022220000000000001111
```

`x = 0x1111` 在最低 8 字节，`y = 0x2222` 在接下来的 8 字节，`z = 0x3333` 在偏移 16 的位置。这和 `docs/evm-storage-endian.md` 是同一件事。

`OptimizedLayout` 的布局是：

```text
| a        | struct OptimizedLayout.Optimized | Slot 0 | 64 bytes |
| balances | mapping(address => uint256)      | Slot 2 | 32 bytes |
```

结构体里两个 `uint128` 占 slot 0，`address` 占 slot 1，mapping 从 slot 2 开始。测试用 `vm.load` 对过这两个字。

这份测试证明的是「打包进了同一个槽」。它没有一份未打包的对照合约，所以 gas report 里看不出省下了几次 `SSTORE`。要量化那个差额，需要另写一个每个变量独占一个槽的合约，再对第一次写入做 trace。协议价目表里，把一个从未写过的槽从 0 写成非 0 是 20000 gas；三个槽对一个槽，多出来的是两次这样的写入，再加冷访问。那是价目表，不是本仓库已经测到的差。

## 其他还在用的工具

### hardhat-gas-reporter

Hardhat 2 的测试在跑 Mocha。插件挂在 `hardhat.config` 上，跑 `npx hardhat test` 时出表，并能把 gas 换成法币，也能拆 L1/L2 的数据费。Foundry 的报告不做法币换算。

```bash
npm install --save-dev hardhat-gas-reporter
```

```ts
import "hardhat-gas-reporter";

const config = {
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    etherscan: process.env.ETHERSCAN_API_KEY,
  },
};
```

平时关掉。它会为了读 gas 多打节点，测试变慢。`2.3.0` 起用法币和 gas price 时走 Etherscan API V2，配置项是 `etherscan`。L2 上的 L1 数据费是估算：作者给 Optimism 的误差大约 1%，Arbitrum 大约 10%。

Hardhat 3 把 snapshot 做进了核心（[gas snapshots](https://hardhat.org/docs/guides/testing/gas-snapshots)）。`hardhat test solidity --snapshot` 写 snapshot，`--snapshot-check` 只比较、不改文件。3.2.0（2026 年 3 月）加了 `--gas-stats-json`。新的 Hardhat 3 项目用这套做回归；还要法币或 L2 数据费时，再用插件。

本仓库的部署编排对照在 `docs/hardhat3-foundry-deploy.md`。gas 数字以 Foundry 这套为准。

### Remix 调试器

Remix 适合看一笔调用里每步还剩多少 gas。调试器跟着 opcode 走，能看见某一步突然掉下去。它不进 CI，也没有 Min/Avg/Max。静态分析插件（Remix Analysis、Solhint，桌面版还能跑 Slither）提示写法，不替代一次 `forge test --gas-report`。

### Slither

`slither` 的优化类检测会指出循环里反复读 storage、可以改成 `immutable` 的变量这一类模式。输出是候选改动。改完用本页的 gas report 再量一次。很多条在开了优化器之后收益很小。

### 已上链的交易

单元测试覆盖不到主网当时的冷热状态和真实 calldata。一笔已经打包的交易，用客户端或区块浏览器看收据里的 `gasUsed`。Tenderly 一类调试器把这笔交易的内部调用和每段 gas 摊开，用途接近本地的 `-vvvv`，对象是主网交易。

收据里的 `gasUsed` 是扣完退款、应用 calldata 下限之后，这笔交易实际收取的 gas。`eth_estimateGas` 是为下一笔交易估 gas limit。两者回答的是不同的问题。Foundry 把这件事写在 [gas accounting](https://www.getfoundry.sh/forge/gas-accounting)。

## 和 Glamsterdam 的关系

这次报告是 Osaka 规则：一种 gas。`vm.lastFrameGas().gasStateUsed` 在这个 EVM 版本上是 0。

EIP-8037 把「新建状态」（新槽、新账户、部署代码）拆成另一维 state gas，计划进 Glamsterdam。2026-10-06 Sepolia 已经激活。Hoodi 原定 2026-10-26 的激活在 10 月 22 日被推迟，当时没有新的日期。主网日期还没定。推迟原因是 EIP-8037 和现有主网合约的交互还要查。来源：[Glamsterdam on Hoodi Postponed](https://blog.ethereum.org/2026/10/22/glamsterdam-hoodi-delay)、[Hoodi 公告](https://blog.ethereum.org/2026/10/16/glamsterdam-hoodi-announcement)。

在 `evm_version = "amsterdam"` 的 Foundry 里，普通 gas 和 state gas 分开记。`gasleft()` 只看普通 gas。收据的 `gasUsed` 已经含两维，不要再加一次 `gasStateUsed`。本仓库测量时主网还没激活，上面的表不要改用 Amsterdam 的价目去解释。

## 在本仓库里怎么选

1. 改函数实现：`forge test --match-path <那个测试> --gas-report`，看函数那一行的 Min/Max，并看 `# Calls` 是不是真的打到了它。
2. 数字奇怪，尤其 Deployment Cost 是 0：同一条测试加 `-vvvv`，读 `→ new` 和每个外部调用的方括号。
3. 准备部署：用已有的 `FOUNDRY_PROFILE=deploy`。它打开优化器、`runs = 1`、去掉 metadata，用来压创建字节码。
4. 要守住回归：对稳定的测试 `forge snapshot --check`。会扫整段字节码的测试，用函数报告做对照。
5. 怀疑槽位浪费：`forge inspect <合约> storageLayout`，再决定要不要改布局。布局改动用一次新的对照测试测量，不从价目表心算当结论。

## 参考

1. [Foundry：Gas tracking](https://www.getfoundry.sh/forge/gas-tracking) — `forge test --gas-report`、snapshot、`pauseGasMetering`
2. [Foundry：Gas accounting](https://www.getfoundry.sh/forge/gas-accounting) — 收据 `gasUsed`、`gasleft()`、EIP-8037 的两维 gas
3. [Foundry：forge snapshot](https://www.getfoundry.sh/reference/forge/snapshot) — `--flamegraph`、`--evm-profile`
4. [Solidity：The Optimizer](https://docs.soliditylang.org/en/latest/internals/optimizer.html) — `optimizer_runs` 的定义
5. [hardhat-gas-reporter](https://github.com/cgewecke/hardhat-gas-reporter) — Hardhat 2 插件，npm `2.3.0`（2025-06-01）
6. [Hardhat 3 gas snapshots](https://hardhat.org/docs/guides/testing/gas-snapshots) — `--snapshot` / `--snapshot-check`
7. [Hardhat 3 is now stable](https://blog.nomic.foundation/hardhat-3-is-now-stable/) — 3.1 的 snapshot、3.2 的 `--gas-stats-json`
8. [eth-gas-reporter](https://github.com/cgewecke/eth-gas-reporter) — 2024 年 3 月归档
9. [EIP-8037](https://eips.ethereum.org/EIPS/eip-8037) — 状态创建的单独计价
10. [Glamsterdam on Hoodi Postponed](https://blog.ethereum.org/2026/10/22/glamsterdam-hoodi-delay) — 2026-10-22 的测试网延期
