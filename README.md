## Foundry + Hardhat 3

合约逻辑测试走 **Foundry**（`forge test`，含 fuzz）。部署和链上交互走 **Hardhat 3** TypeScript 脚本（`hardhat run`）。Solidity 仍在 `src/`，Foundry 脚本仍在 `script/`，Hardhat 脚本在 `scripts/`。

### 分工

| 事情 | 工具 |
| --- | --- |
| 编译 / 单测 / fuzz | Foundry：`forge build`、`forge test` |
| TS 脚本、发交易、读状态 | Hardhat 3：`pnpm hardhat run scripts/... --network <name>` |
| 本地节点 | `anvil` 或 `pnpm hardhat node` |

Hardhat 只编译 `src/`，不跑 `test/*.t.sol`。Solidity 测试继续用 Foundry。

## Foundry

https://book.getfoundry.sh/

### Build / Test / Format

```shell
forge build
forge test
forge fmt
```

### Anvil

```shell
anvil
```

### Deploy（Solidity script，可选）

```shell
source .env
forge script script/Counter.s.sol:CounterScript --rpc-url sepolia --broadcast --private-key $SEPOLIA_PRIVATE_KEY
cast send <contract address> "setNumber(uint256)" 42 --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY
cast call <contract address> "number()" --rpc-url sepolia
```

### Verify

```bash
./script/verify.sh src/MyTokenV1.sol:MyTokenV1 0x8b0F9023d0a917503Cd247bD9985B6527E4fA846
```

## Hardhat 3

需要 Node.js `>= 22.13.0`。

```shell
pnpm install
cp .env.example .env   # 填写 SEPOLIA_PRIVATE_KEY；RPC 可用 SEPOLIA_RPC_URL 或 FOUNDRY_RPC_ENDPOINTS
```

配置变量默认从环境变量读取（`hardhat.config.ts` 会加载 `.env`）。也可以放进 Hardhat keystore：

```shell
pnpm hardhat keystore set SEPOLIA_PRIVATE_KEY --dev
pnpm hardhat keystore set SEPOLIA_RPC_URL --dev
```

### 编译合约

```shell
pnpm hardhat build
```

### 网络

- 默认：Hardhat 内存链 `hardhatMainnet`（不需要节点）
- `localhost`：`http://127.0.0.1:8545`（先开 `anvil` 或 `pnpm hardhat node`）
- `sepolia`：用 `.env` 里的 RPC 和私钥

Hardhat 内存链每次 `hardhat run` 都是新链，合约不会跨进程保留。要在两次脚本之间复用地址，请用 `localhost`（anvil / `hardhat node`）或 `sepolia`。`interact-*.ts` 若发现地址上没有 bytecode，会自动再部署一次。

### 发交易示例（Counter）

内存链（部署 + 发交易在同一次运行里完成）：

```shell
pnpm hardhat run scripts/interact-counter.ts
```

本地 anvil：

```shell
anvil
pnpm hardhat run scripts/deploy-counter.ts --network localhost
pnpm hardhat run scripts/interact-counter.ts --network localhost
```

Sepolia：

```shell
pnpm hardhat run scripts/accounts.ts --network sepolia
pnpm hardhat run scripts/deploy-counter.ts --network sepolia
pnpm hardhat run scripts/interact-counter.ts --network sepolia
```

`interact-counter.ts` 会 `setNumber` 再 `increment`。可用环境变量覆盖：

```shell
COUNTER_ADDRESS=0x... NUMBER=7 pnpm hardhat run scripts/interact-counter.ts --network sepolia
```

### 其他脚本

| 脚本 | 作用 |
| --- | --- |
| `scripts/accounts.ts` | 打印当前账户和余额 |
| `scripts/deploy-my-token-v1.ts` | 部署 MyTokenV1 |
| `scripts/deploy-token-bank-v1.ts` | 部署 MyTokenV1 + TokenBankV1 |
| `scripts/deploy-token-bank-v2.ts` | 部署 MyTokenV1 + TokenBankV2 |
| `scripts/deploy-token-bank-erc1363.ts` | 部署 MyTokenERC1363 + TokenBankERC1363 |
| `scripts/deploy-eth-bank.ts` | 部署 ETHBank 并存款 |
| `scripts/interact-token-bank-v2.ts` | approve + deposit |

部署地址写到 `deployments/<Name>/<Name>_<chainId>.json`，和 Foundry `BaseScript` 同一目录。
