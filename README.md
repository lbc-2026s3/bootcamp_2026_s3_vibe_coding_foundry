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