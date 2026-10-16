# SocialRecoveryWallet — 社交恢复钱包

多签是每一笔转账都要凑够 M 个签名。社交恢复把这两件事拆开：平时只有主人一把钥匙能花钱；这把钥匙丢了，才由守护者一起指定一个新主人。守护者平时不能转账。

资料里的片段只写了 `initiateRecovery` 和 `confirmRecovery`。确认数一到 `threshold`，下一行就是 `owner = recovery.newOwner`。那个 `3 days` 是投票截止时间：过了就不能再确认。它不是换主人之前的等待。两名守护者在同一个区块里确认，主人会立刻被换掉，旧钥匙没有取消的入口。钱包也没有转账函数，所以看不出「钱还在、钥匙丢了」这件事。

## 流程

默认是 3 名守护者、门槛 2、安全期 3 天。

```
空闲
    owner.execute：只有主人能把 ETH 转走
    │
    ▼
收集  initiateRecovery(newOwner)     任意一名守护者，算第 1 票
      confirmRecovery()              其他守护者各算 1 票
    │  从这一刻起钱包上锁：不能转账，也不能更换守护者
    │  确认数不到 2，就一直停在这里，到不了换主人
    ▼
等待  第 2 票到达的那一刻记下 executableAt = now + 3 days
    │  owner 还是旧地址
    │  旧钥匙如果还在，cancelRecovery() 会把这一轮清掉
    ▼
生效  block.timestamp >= executableAt
      任何人 executeRecovery()
      owner 换成 newOwner，锁打开，新主人可以 execute
```

`executableAt` 那一秒起就可以执行恢复。合约不会自己到点换主人，得有人发交易。

## 两段时间不要混

| | 资料片段 | 这个合约 |
|---|---|---|
| 3 天的含义 | 投票窗口，过了不能再确认 | 票凑满之后的安全期 |
| 票凑满时 | 立刻 `owner = newOwner` | 只记下 `executableAt`，主人不变 |
| 旧钥匙 | 没有取消函数 | 安全期结束前可以 `cancelRecovery` |
| 钱 | 没有转出函数 | 只有 `owner` 能 `execute` |

安全期防的是守护者串通，而且主人的钥匙还在。一名守护者就能发起恢复并锁上钱包，主人取消即可，这是用一次取消换「丢钥匙时钱不会被立刻转走」。

钥匙如果已经被偷，小偷就是当前 `owner`。他可以先 `cancelRecovery`，再把钱转走。社交恢复解决的是钥匙丢失，不是钥匙被盗。

## 文件

| 路径 | 作用 |
|---|---|
| `src/wallet/SocialRecoveryWallet.sol` | 钱包合约 |
| `script/wallet/DeploySocialRecoveryWallet.s.sol` | 部署。anvil 账户 0 是主人，账户 1/2/3 是守护者，门槛 2，安全期 3 天，并打入 1 ETH |
| `test/wallet/SocialRecoveryWallet.t.sol` | 测试 |

## 用法

```bash
forge test --match-path test/wallet/SocialRecoveryWallet.t.sol -vv

forge script script/wallet/DeploySocialRecoveryWallet.s.sol:DeploySocialRecoveryWallet \
  --broadcast --rpc-url local \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  && cat ./deployments/LATEST.txt
```

部署用的是 anvil 公开的默认账户私钥，只给本地链用。
