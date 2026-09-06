## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

#### src/Counter.sol
```shell
$ source .env
$ forge script script/Counter.s.sol:CounterScript --rpc-url sepolia --broadcast --private-key $SEPOLIA_PRIVATE_KEY
$ cast send <contract address> "setNumber(uint256)" 42 --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY
$ cast call <contract address> "number()" --rpc-url sepolia
```

#### src/ETHBank.sol
```shell
$ source .env
# 部署(本地 anvil:anvil 默认账户 0 的私钥 / sepolia:使用 .env 中的私钥)
$ forge script script/ETHBank.s.sol:ETHBankScript --rpc-url local --broadcast --private-key <private-key>
$ forge script script/ETHBank.s.sol:ETHBankScript --rpc-url sepolia --broadcast --private-key $SEPOLIA_PRIVATE_KEY
# 存款(也可用 MetaMask 直接向合约地址转账 ETH,receive() 会自动记账)
$ cast send <contract address> "deposit()" --value 1ether --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY
# 查询存款前三(按存款金额降序)
$ cast call <contract address> "getTop3()" --rpc-url sepolia
# 仅管理员(部署者)可提取合约内全部 ETH
$ cast send <contract address> "withdraw()" --rpc-url sepolia --private-key $SEPOLIA_PRIVATE_KEY
```