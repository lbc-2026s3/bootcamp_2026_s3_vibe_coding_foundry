记录部署 MyERC721UpgradeableNFT 和 Proxy 的地址

# 部署 MyERC721UpgradeableNFT 和 Proxy
```shell
forge script script/upgradeable/MyERC721UpgradeableNFT.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

输出：
MyERC721UpgradeableNFT => 0x1f728925034293943C9Fde0cC3E3E1D5a79E57b3

MyERC721UpgradeableNFT_Implementation => 0xC214FDA87a4f0053E62AC2C8c6c127C864b61EBB


# 验证 MyERC721UpgradeableNFT 和 Proxy
```shell
script/verify.sh \
  src/upgradeable/MyERC721UpgradeableNFT.sol:MyERC721UpgradeableNFT \
  0xC214FDA87a4f0053E62AC2C8c6c127C864b61EBB
```

```shell
script/verify.sh \
  lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  0x1f728925034293943C9Fde0cC3E3E1D5a79E57b3 \
  --constructor address,bytes \
  0xC214FDA87a4f0053E62AC2C8c6c127C864b61EBB,0xc4d66de8000000000000000000000000cfeae9d951107b18c3495247d8249ad005175707
```



# 升级
```shell
forge script script/upgradeable/MyERC721UpgradeableNFTV2.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

输出：
MyERC721UpgradeableNFT => 0x1f728925034293943C9Fde0cC3E3E1D5a79E57b3

MyERC721UpgradeableNFT_Implementation => 0xe96b1bb803Ee488B2f5D0FFEEc9a3C15a8Fa654e

# 验证 MyERC721UpgradeableNFTV2

```shell
script/verify.sh \
  src/upgradeable/MyERC721UpgradeableNFTV2.sol:MyERC721UpgradeableNFTV2 \
  0xe96b1bb803Ee488B2f5D0FFEEc9a3C15a8Fa654e

```


# 汇总
Proxy: https://sepolia.etherscan.io/address/0x1f728925034293943C9Fde0cC3E3E1D5a79E57b3

MyERC721UpgradeableNFT: https://sepolia.etherscan.io/address/0xC214FDA87a4f0053E62AC2C8c6c127C864b61EBB

MyERC721UpgradeableNFTV2: https://sepolia.etherscan.io/address/0xe96b1bb803Ee488B2f5D0FFEEc9a3C15a8Fa654e