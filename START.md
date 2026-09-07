# 开始：Foundry + Hardhat 3

这个仓库同时用 **Foundry** 和 **Hardhat 3**。合约只写一份（`src/`），两套工具各干各的：

| 你要做的事 | 用哪个 | 命令 |
| --- | --- | --- |
| 编译 / 单测 / fuzz | Foundry | `forge build`、`forge test` |
| TypeScript 脚本、发交易、读链上状态 | Hardhat 3 | `pnpm hardhat run scripts/... --network <网络>` |
| 本地节点 | 任选 | `anvil` 或 `pnpm hardhat node` |

不要用 Hardhat 跑 `test/*.t.sol`。Solidity 测试只走 Foundry。

---

## 环境

- Foundry（`forge` / `cast` / `anvil`）：https://book.getfoundry.sh/getting-started/installation
- Node.js **>= 22.13.0**
- pnpm（Hardhat 3 推荐）

```shell
git clone <本仓库> && cd bootcamp_2026_s3_vibe_coding_foundry
git submodule update --init --recursive   # lib/forge-std、lib/openzeppelin-contracts
pnpm install
cp .env.example .env                      # 填私钥；RPC 见下文
```

`.env` 两套工具共用，**不要提交**。

```
FOUNDRY_RPC_ENDPOINTS={sepolia="https://..."}   # Foundry 的 sepolia RPC
SEPOLIA_RPC_URL=                                 # Hardhat 优先用这个；空则解析上一行
SEPOLIA_PRIVATE_KEY=0x...                        # 两套共用，Hardhat 建议带 0x
ETHERSCAN_API_KEY=
```

---

## 项目结构

```
.
├── src/                      # Solidity 合约（唯一源码，两套工具都编译这里）
│   ├── Counter.sol
│   ├── ETHBank.sol
│   ├── MyTokenV1.sol
│   ├── MyTokenERC1363.sol
│   ├── TokenBankV1.sol
│   ├── TokenBankV2.sol
│   └── TokenBankERC1363.sol
│
├── test/                     # Foundry 测试（*.t.sol，含 fuzz）
├── script/                   # Foundry Solidity 脚本（forge script）
│   ├── BaseScript.s.sol      # 部署后写入 deployments/
│   └── verify.sh             # forge verify-contract
│
├── scripts/                  # Hardhat TypeScript 脚本（hardhat run）
│   ├── lib/
│   │   ├── connect.ts        # 连网、拿钱包
│   │   └── deployments.ts    # 读写 deployments/，格式对齐 BaseScript
│   ├── accounts.ts
│   ├── deploy-*.ts
│   └── interact-*.ts
│
├── lib/                      # git submodule：forge-std、openzeppelin-contracts
├── remappings.txt            # import 路径（Hardhat 3 也会读）
├── foundry.toml              # Foundry 配置
├── hardhat.config.ts         # Hardhat 3 配置（sources=./src）
├── package.json              # Hardhat / viem / TypeScript
├── deployments/              # 部署记录（git 忽略）
│   └── <合约名>/<合约名>_<chainId>.json
├── out/                      # Foundry 编译产物
└── artifacts/                # Hardhat 编译产物
```

注意两个脚本目录：**`script/`**（Foundry，Solidity）和 **`scripts/`**（Hardhat，TypeScript）。

---

## Foundry：测合约

```shell
forge build
forge test
forge test --match-contract CounterTest -vvv
forge fmt
```

`pnpm test` 也是 `forge test`。

可选：用 Foundry 部署（和 Hardhat 脚本二选一即可）：

```shell
source .env
forge script script/Counter.s.sol:CounterScript --rpc-url sepolia --broadcast --private-key $SEPOLIA_PRIVATE_KEY
cast send <地址> "setNumber(uint256)" 42 --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY
cast call <地址> "number()" --rpc-url sepolia
```

验证：

```shell
./script/verify.sh src/MyTokenV1.sol:MyTokenV1 0x...
```

---

## Hardhat 3：TS 脚本和发交易

```shell
pnpm hardhat build
```

### 网络

| `--network` | 含义 |
| --- | --- |
| 不写（默认） | 内存链。每次 `hardhat run` 都是新链，合约不会留给下一次 |
| `localhost` | `http://127.0.0.1:8545`，先开 `anvil` 或 `pnpm hardhat node` |
| `sepolia` | 用 `.env` 的 RPC + 私钥 |

要在「部署」和「发交易」两次命令之间复用合约，用 `localhost` 或 `sepolia`。`interact-*.ts` 如果发现地址上没有 bytecode，会自动再部署一次。

### 最短路径（内存链，一次跑完部署 + 交易）

```shell
pnpm hardhat run scripts/interact-counter.ts
```

会部署 Counter，再 `setNumber(42)`、`increment()`，最后打印 `number()`。

### 本地 anvil

```shell
anvil    # 另开一个终端
pnpm hardhat run scripts/deploy-counter.ts --network localhost
pnpm hardhat run scripts/interact-counter.ts --network localhost
```

### Sepolia

```shell
pnpm hardhat run scripts/accounts.ts --network sepolia
pnpm hardhat run scripts/deploy-counter.ts --network sepolia
pnpm hardhat run scripts/interact-counter.ts --network sepolia
```

覆盖地址 / 参数：

```shell
COUNTER_ADDRESS=0x... NUMBER=7 pnpm hardhat run scripts/interact-counter.ts --network sepolia
```

### 脚本一览

| 脚本 | 做什么 |
| --- | --- |
| `scripts/accounts.ts` | 当前账户和余额 |
| `scripts/deploy-counter.ts` | 部署 Counter |
| `scripts/interact-counter.ts` | 部署（如需要）+ `setNumber` + `increment` |
| `scripts/deploy-my-token-v1.ts` | 部署 MyTokenV1 |
| `scripts/deploy-token-bank-v1.ts` | MyTokenV1 + TokenBankV1 |
| `scripts/deploy-token-bank-v2.ts` | MyTokenV1 + TokenBankV2 |
| `scripts/deploy-token-bank-erc1363.ts` | MyTokenERC1363 + TokenBankERC1363 |
| `scripts/deploy-eth-bank.ts` | 部署 ETHBank 并存款 |
| `scripts/interact-token-bank-v2.ts` | approve + deposit |

部署地址写入 `deployments/<Name>/<Name>_<chainId>.json`，和 Foundry `BaseScript` 同一格式。

私钥也可以放进 Hardhat keystore（可选，不用 `.env` 里的明文）：

```shell
pnpm hardhat keystore set SEPOLIA_PRIVATE_KEY --dev
pnpm hardhat keystore set SEPOLIA_RPC_URL --dev
```

---

## 日常建议

1. 改合约 → `forge test`（含 fuzz）通过后再部署。
2. 发交易、读链、写 TS 流程 → Hardhat `scripts/`。
3. 不要把 `.env`、私钥、`deployments/` 提交进 git。
