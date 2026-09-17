记录部署 Counter Beacon Proxy 相关地址

# 部署 CounterBeaconFactory（V1 impl + Beacon + 两份 Proxy）

```shell
forge script script/upgradeable/beacon_proxy/CounterBeaconFactory.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

输出字段示例：

- CounterBeaconFactory: https://repo.sourcify.dev/11155111/0x6ac7AE80D87B186E8f2D403e294b058C8Cd3eb30

- CounterBeaconFactory => 0x6ac7AE80D87B186E8f2D403e294b058C8Cd3eb30
- Counter_UpgradeableBeacon => 0x07b993Cb40585041C0962EDeCbBC0f4FAe77cDe2
- Counter_Implementation(V1) => 0xdC72C1952864316427cFEf213886626aCdC5531b
- Counter_BeaconProxyA => 0xA5b45874C0A4ED2e30C1B8D0E5bB2ED79D84d882
- Counter_BeaconProxyB => 0x4196838546A677C8f30476365C07Ea6dA8771FDD

# 升级到 CounterV2

```shell
forge script script/upgradeable/beacon_proxy/CounterV2.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

也可显式指定 factory：

```shell
FACTORY=0x... forge script script/upgradeable/beacon_proxy/CounterV2.s.sol --broadcast \
    --rpc-url sepolia \
    --private-key $SEPOLIA_PRIVATE_KEY && cat ./deployments/LATEST.txt
```

输出字段示例：

- CounterBeaconFactory => 0x6ac7AE80D87B186E8f2D403e294b058C8Cd3eb30
- Counter_UpgradeableBeacon => 0x07b993Cb40585041C0962EDeCbBC0f4FAe77cDe2
- Counter_Implementation => 0xf8736AD173d18D17C431aE95AdAe06F050fa710b

```shell
script/verify.sh \
  src/upgradeable/beacon_proxy/CounterV2.sol:CounterV2 \
  0xf8736AD173d18D17C431aE95AdAe06F050fa710b
```

# 说明

- 升级在 `UpgradeableBeacon.upgradeTo`（经 factory 的 `onlyOwner` 转发），一次升级影响所有 BeaconProxy。
- beacon 的 owner 是 factory；factory 的 owner 是部署人（生产应交给 multisig/timelock）。
- 当前逻辑地址读 `beacon.implementation()`。
- 实现合约不使用 UUPS。
