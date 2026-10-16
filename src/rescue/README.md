# 泄漏地址抢救演练

受害者的私钥已经泄漏，ETH 为 0。链上还有 3 枚 NFT 和 100 个 LAB（ERC20，18 位小数）。赞助者是干净地址，由赞助者支付 gas，用一笔 EIP-7702 交易把资产转走。受害者的 ETH 余额全程是 0。

两把私钥都放在项目根目录的 `.env`。Foundry 会自动加载，脚本用 `vm.envUint` 读取。命令行不要写 `--private-key`。

| 变量 | 角色 |
| --- | --- |
| `RESCUE_SPONSOR_KEY` | 赞助者。支付 gas，部署合约，接收 LAB 和 NFT。Sepolia 上这个地址要有 ETH。 |
| `RESCUE_VICTIM_KEY` | 受害者。只签名，不发交易。对应地址的 ETH 必须是 0。 |

本地 anvil 可以把公开测试私钥写进 `.env`（anvil 第一个账户，以及一把不会被预置 ETH 的私钥）：

```bash
RESCUE_SPONSOR_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RESCUE_VICTIM_KEY=0x1111111111111111111111111111111111111111111111111111111111111111
```

Sepolia 换成自己的测试私钥。赞助者可以沿用已有的 `SEPOLIA_PRIVATE_KEY`。受害者用一把新私钥，不要给它领水龙头。主网会被脚本拒绝。

## 1. 启动本地链

Sepolia 跳过这一步。`.env` 里的 `FOUNDRY_RPC_ENDPOINTS` 需要包含 `sepolia`。

```bash
anvil
```

## 2. 准备环境

部署 `LabERC20`、`LabNFT`、`RescueDelegate`（收款地址写死为赞助者），给受害者铸造 100 个 LAB 和 3 枚 NFT。此时受害者的 ETH 仍是 0。

合约地址和 tokenId 写入 `deployments/RescuePlan/RescuePlan_<chainId>.json`。anvil 的 chainId 是 31337，Sepolia 是 11155111，两份记录互不覆盖。

本地：

```bash
forge script script/rescue/PrepareRescueEnv.s.sol:PrepareRescueEnv \
  --broadcast --rpc-url local \
  && cat ./deployments/LATEST.txt
```

Sepolia 上创建合约的实际 gas 大约是 Forge 原始估算的 7 倍。乘数是百分比：`600` 表示 6 倍，仍然低于节点要价，部署会把 gas 用尽。`800` 表示 8 倍，三笔部署都高于节点估算，最大的一笔大约 1440 万 gas，低于 Sepolia 单笔上限 16777216。

```bash
forge script script/rescue/PrepareRescueEnv.s.sol:PrepareRescueEnv \
  --broadcast --rpc-url sepolia --gas-estimate-multiplier 800 \
  && cat ./deployments/LATEST.txt
```

## 3. 营救

赞助者发送一笔 type-4 交易。Gas 从赞助者扣。LAB 和 3 枚 NFT 转到赞助者。

本地：

```bash
forge script script/rescue/RescueCompromisedWallet.s.sol:RescueCompromisedWallet \
  --broadcast --rpc-url local
```

Sepolia：

```bash
forge script script/rescue/RescueCompromisedWallet.s.sol:RescueCompromisedWallet \
  --broadcast --rpc-url sepolia --gas-estimate-multiplier 800
```

某一枚 NFT 转失败时，资产转账会撤销，受害者上的 LAB 和 NFT 保持原样。按 EIP-7702，这次写入的委托不会跟着撤销。委托只能把资产转到赞助者，所以赞助者可以再发一笔普通调用完成转移，仍然不用给受害者打 ETH。

## 4. 核对

把下面的地址换成 `deployments/LATEST.txt` 里的值。受害者地址在准备脚本的日志里。`--rpc-url` 本地用 `local`，Sepolia 用 `sepolia`。

```bash
cast balance <victim> --rpc-url local
cast call <LabERC20> "balanceOf(address)(uint256)" <victim> --rpc-url local
cast call <LabERC20> "balanceOf(address)(uint256)" <sponsor> --rpc-url local
cast call <LabNFT> "ownerOf(uint256)(address)" 1 --rpc-url local
cast code <victim> --rpc-url local
```

预期：

- 受害者的 ETH 是 0。
- 受害者的 LAB 是 0。赞助者的 LAB 原始数量是 `100000000000000000000`（100 个，18 位小数）。
- NFT 1、2、3 的 `ownerOf` 是赞助者。
- `cast code` 看到 `0xef0100` 开头的 23 字节。这是 7702 委托标记，后面 20 字节是 `RescueDelegate` 的地址。委托会留到下一笔授权把它换掉。这个合约只能把资产转到赞助者。

单元测试（不需要 anvil，也不读 `.env`）：

```bash
forge test --match-path test/rescue/RescueCompromisedWallet.t.sol -vv
```

其中 `test_fundingTransactionIsSweptAndNftsStay` 演示另一条路：先给受害者转入 1 ETH，同一把私钥的下一笔交易把 ETH 转走，NFT 仍留在受害者地址上。
