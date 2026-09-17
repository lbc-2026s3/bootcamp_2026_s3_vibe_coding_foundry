1. 先运行 NFTMarketPermitV1.s.sol 脚本部署 MyTokenERC2612Permit、MyERC721UpgradeableNFT、NFTMarketPermitV1

```shell
forge script script/upgradeable/market/NFTMarketPermitV1.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

输出：

```
MyTokenERC2612Permit => 0xab1E58F6865A8695bfF2969E6408f0783BE72B41
MyERC721UpgradeableNFT => 0xC7cF55d58dAb3357498f17b03B82e9E3DF00A7f5
MyERC721UpgradeableNFT_Implementation => 0x215EdfcdcE00A659b6f30F63420a5a79d59738b6
NFTMarketPermitV1 => 0x9A4E9E789070D7e898f2B6c844323685b1f21966
NFTMarketPermitV1_Implementation => 0xf6a585f3da0Daf7b89CFeA065DD929D4921aD84D
```

2. 验证 NFTMarketPermitV1 Implementation + Proxy

# Implementation（无构造参数）
```shell
script/verify.sh \
  src/upgradeable/market/NFTMarketPermitV1.sol:NFTMarketPermitV1 \
  0xf6a585f3da0Daf7b89CFeA065DD929D4921aD84D
```

# ERC1967Proxy（构造参数: implementation + initialize calldata）
# initialize(token, nft, deployer)：
#   token    0xab1E58F6865A8695bfF2969E6408f0783BE72B41
#   nft      0xC7cF55d58dAb3357498f17b03B82e9E3DF00A7f5
#   deployer 0xcfeae9d951107b18c3495247d8249ad005175707
```shell
script/verify.sh \
  lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  0x9A4E9E789070D7e898f2B6c844323685b1f21966 \
  --constructor address,bytes \
  0xf6a585f3da0Daf7b89CFeA065DD929D4921aD84D,0xc0c53b8b000000000000000000000000ab1e58f6865a8695bff2969e6408f0783be72b41000000000000000000000000c7cf55d58dab3357498f17b03b82e9e3df00a7f5000000000000000000000000cfeae9d951107b18c3495247d8249ad005175707
```


3. 升级 NFTMarketPermitV1 为 NFTMarketPermitV2

```shell
forge script script/upgradeable/market/NFTMarketPermitV2.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

输出:
```
NFTMarketPermitV1 => 0x9A4E9E789070D7e898f2B6c844323685b1f21966
NFTMarketPermitV2 => 0x9A4E9E789070D7e898f2B6c844323685b1f21966
NFTMarketPermitV2_Implementation => 0x302AF6B98aAf2875244BC924f5Fa8dc1A349D373
```

4. 验证 NFTMarketPermitV2_Implementation

```shell
script/verify.sh \
  src/upgradeable/market/NFTMarketPermitV2.sol:NFTMarketPermitV2 \
  0x302AF6B98aAf2875244BC924f5Fa8dc1A349D373
```

5. 地址汇总
```
NFTMarket Proxy: https://sepolia.etherscan.io/address/0x9A4E9E789070D7e898f2B6c844323685b1f21966

v1: https://sepolia.etherscan.io/address/0xf6a585f3da0Daf7b89CFeA065DD929D4921aD84D

v2: https://sepolia.etherscan.io/address/0x302AF6B98aAf2875244BC924f5Fa8dc1A349D373
```