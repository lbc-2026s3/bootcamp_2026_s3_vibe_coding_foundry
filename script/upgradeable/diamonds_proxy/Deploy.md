记录部署 PointsVault Diamond 相关地址

# 部署钻石（Cut + Loupe + Ownership + Vault V1）

```shell
forge script script/upgradeable/diamonds_proxy/DeployDiamond.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

用户始终与 `PointsVaultDiamond` 交互；facet 地址只是逻辑实现。

# Add PointsFacet

```shell
forge script script/upgradeable/diamonds_proxy/UpgradeAddPoints.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

也可显式指定钻石：

```shell
DIAMOND=0x... forge script script/upgradeable/diamonds_proxy/UpgradeAddPoints.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

# Replace withdraw → VaultFacetV2（1% 手续费）

```shell
forge script script/upgradeable/diamonds_proxy/UpgradeReplaceVault.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

# 说明

- 升级入口是 `diamondCut`（经 `DiamondCutFacet`），权限在钻石 `owner`（生产应交给 multisig/timelock）。
- Add：挂上新 selector（`pointsOf`），并 Replace 已有 `deposit`。
- Replace：同一 selector 换 facet，AppStorage 不迁移。
- Remove：见测试 `test_RemoveExperimentalSelector`。
