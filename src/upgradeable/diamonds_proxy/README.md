# PointsVault Diamond

用 **EIP-2535 钻石代理** 做一份可按函数粒度升级的 ETH 金库：同一地址先存款，再挂积分，再给取款加手续费。

对照：

| 模式 | 位置 | 升级单位 | 对外地址 |
|------|------|----------|----------|
| UUPS | [`src/upgradeable/MyERC721UpgradeableNFT.sol`](../MyERC721UpgradeableNFT.sol) | 整份 implementation | 1 个 proxy |
| Beacon | [`src/upgradeable/beacon_proxy/`](../beacon_proxy/) | 整份 implementation | N 个 proxy 共享 1 个 beacon |
| **Diamond** | 本目录 | **单个 selector**（Add / Replace / Remove） | **1 个钻石地址** |

## 为什么不用 UUPS / Beacon？

- **UUPS / Beacon**：一次换掉整份逻辑合约。适合「一个模块长期演进」。
- **Diamond**：`fallback` 按 `msg.sig` 查表再 `delegatecall` 到不同 facet。适合「一个协议拆成多个模块、分别升级」，也能绕过单合约 24KB 限制。

OpenZeppelin 没有官方 Diamond；本示例按 [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535) 精简实现，不引入 Hardhat 依赖。

## 这个 demo 在演示什么？

假想你上线了一个很简单的 **ETH 金库**：用户往合约里存 ETH、查余额、再取出来。  
对外只有一个地址 `PointsVaultDiamond`——用户钱包、前端、浏览器里看到的合约地址永远不变。

钻石代理要证明的是：这个地址背后的能力可以**按功能一块一块地加 / 换 / 删**，而不必像 UUPS 那样整份逻辑一起换。

### 关键函数（都打在钻石地址上）

| 函数 | 谁调用 | 做什么 |
|------|--------|--------|
| `deposit()` | 用户 | 向金库存入 ETH（`msg.value`），增加该用户记账余额。V1 只记账；挂上积分后，新存款还会按 1 wei = 1 积分发分。 |
| `withdraw(amount)` | 用户 | 从金库取出 `amount` ETH 到调用者。V1 全额取出；换成 V2 后按 `withdrawFeeBps` 扣手续费，实到手 = amount − fee。 |
| `pointsOf(user)` | 任意人（只读） | 查询 `user` 当前积分。Add 之前钻石上没有这个函数；Add 之后才能调。 |
| `withdrawFeeBps()` | 任意人（只读） | 查询取款手续费率（basis points，100 = 1%）。Replace 到 V2 时一并 Add。 |
| `protocolFees()` | 任意人（只读） | 查询合约里累计扣留的手续费总额（ETH 仍留在钻石地址上）。 |
| `diamondCut(...)` | 仅 owner | 升级入口：给钻石 **Add / Replace / Remove** 函数（selector → facet）。用户存取款不调它；产品迭代才调它。 |

（另有 `balanceOf` / `totalDeposits` 查余额与总存款，以及 Loupe / Ownership 等基础设施函数，见架构一节。）

### 产品迭代四步

1. **先上线最小金库（V1）**  
   只有存、取、查余额。用户 Alice 存入 2 ETH，合约记下她的余额。

2. **产品要加「积分」：给钻石挂上新函数，并改写存款逻辑**  
   - **Add** `pointsOf`：以前没有，挂上后才能查积分  
   - **Replace** `deposit`：换成「存款时顺便发积分」的实现  
   - Alice 之前那 2 ETH **还在**（状态存在钻石自己的存储里，不跟 facet 走）；之后再存 1 ETH，才会开始有积分。

3. **产品要收 1% 取款手续费：只换取款，不动存款 / 积分**  
   - **Replace** `withdraw`：换成带手续费的版本  
   - **Add** `withdrawFeeBps` / `protocolFees`：方便查询费率与累计手续费  
   - 费率通过 `diamondCut` 时的一次性 init 写入；Alice 的余额和积分都还在。

4. **实验功能可以卸掉（Remove）**  
   测试里临时挂上一个 `ping()`，再 Remove 掉。卸掉之后再调就会失败——说明钻石不仅可以加能力，也可以裁剪能力。

一句话：**用户始终打同一个合约地址；owner 用 `diamondCut` 决定这个地址此刻能调哪些函数、每个函数跑哪段逻辑。**

## 架构

```mermaid
flowchart TB
  User --> Diamond
  Diamond -->|"fallback: selector → facet"| LibDiamond
  LibDiamond --> Cut[DiamondCutFacet]
  LibDiamond --> Loupe[DiamondLoupeFacet]
  LibDiamond --> Own[OwnershipFacet]
  LibDiamond --> Vault[VaultFacet / VaultFacetV2]
  LibDiamond --> Points[PointsFacet]
  Vault --> AppStorage
  Points --> AppStorage
```

```text
Diamond（唯一对外地址）
├── DiamondCutFacet       // diamondCut
├── DiamondLoupeFacet     // facets / facetAddress / supportsInterface
├── OwnershipFacet        // owner / transferOwnership
├── VaultFacet            // deposit / withdraw / balanceOf / totalDeposits
├── PointsFacet           // （Cut 后）pointsOf + 新的 deposit
└── VaultFacetV2          // （Cut 后）withdraw + 费率只读

AppStorage（独立 slot，所有 facet 共享）
├── balances / points / totalDeposits
└── withdrawFeeBps / protocolFees / v2Initialized   // V2 只能追加
```

## 文件

| 文件 | 作用 |
|------|------|
| [`Diamond.sol`](./Diamond.sol) | 构造时挂 V1 facets；`fallback` 路由 |
| [`libraries/LibDiamond.sol`](./libraries/LibDiamond.sol) | selector 表 + `diamondCut` |
| [`libraries/LibAppStorage.sol`](./libraries/LibAppStorage.sol) | 业务存储 |
| [`facets/`](./facets/) | Cut / Loupe / Ownership / Vault / Points / Experimental |
| [`inits/VaultV2Init.sol`](./inits/VaultV2Init.sol) | 不挂到钻石上，仅 `delegatecall` 写费率 |

相关测试 / 脚本：

- [`test/upgradeable/diamonds_proxy/PointsVaultDiamond.t.sol`](../../../test/upgradeable/diamonds_proxy/PointsVaultDiamond.t.sol)
- [`script/upgradeable/diamonds_proxy/`](../../../script/upgradeable/diamonds_proxy/)（含 [`Deploy.md`](../../../script/upgradeable/diamonds_proxy/Deploy.md)）

## 关键规则

1. 用户只调钻石地址；直接调 facet 不会写钻石存储。
2. facet **禁止**用构造函数写业务状态；状态走 `LibAppStorage`。
3. `diamondCut` 仅 owner。生产环境应把 owner 交给 multisig/timelock（owner 可 Remove 关键函数）。
4. AppStorage 只能追加字段。V2 费率通过独立 init 合约写入，不把 `init` 留在钻石 selector 表上。
5. 存取款走 Checks-Effects-Interactions + OZ `ReentrancyGuard`（ERC-7201 槽，各 facet 共享同一把锁）。
6. 禁止 `receive()` 裸入 ETH，必须走 `deposit()`。
7. V2 扣费后不变量：`address(diamond).balance == totalDeposits() + protocolFees()`（手续费仍留在钻石上；本 demo 不提供 claim，后续可再 Add sweep facet）。

## 本地验证

```shell
forge test --match-path 'test/upgradeable/diamonds_proxy/*' -vv
```

覆盖点：状态写在钻石上、Loupe 路由、Add 积分后旧余额仍在、Replace 取款扣费且积分不丢、Remove 末尾 / 中间 selector、非 owner / 冲突 selector 失败、费率 init 与 fuzz 取款。

## 部署

见 [`script/upgradeable/diamonds_proxy/Deploy.md`](../../../script/upgradeable/diamonds_proxy/Deploy.md)。
