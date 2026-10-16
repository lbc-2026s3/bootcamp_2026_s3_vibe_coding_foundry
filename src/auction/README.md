# SealedBidAuction — 首价密封拍卖

公开出价把金额写在交易的 `msg.value` 里。交易进内存池之后、被打包之前，所有人都能看见。别人可以加一点点，并出更高的 gas price，让自己的出价排在前面。

这个合约改成密封投标：提交期只交哈希，互相看不见金额；提交窗口关闭后才披露。成交价是赢家自己的出价。价格相同的时候，先披露的人保持领先。

## 流程

```
部署（卖家 = 部署人，锁定两个窗口和保证金）
    │
    ▼
提交期 [now, commitDeadline)
    commit(hash)：交哈希 + 一笔相同的保证金
    │
    ▼
披露期 [commitDeadline, revealDeadline)
    reveal(金额, secret)：打入与承诺相同的 ETH
    │
    ▼
结束 [revealDeadline, ∞)
    finalize()：卖家记下最高出价，赢家记下保证金
    withdraw()：各自把 ETH 取走
```

`commitDeadline` 那一秒起不能再提交，可以开始披露。`revealDeadline` 那一秒起不能再披露，可以结算和取款。

## 承诺

链下和合约用同一个公式：

```solidity
keccak256(abi.encode(bidder, bidAmount, secret))
```

`secret` 用足够长的随机数。只哈希金额的话，出价通常是整数 ETH，别人可以把 `1 ether`、`2 ether`……穷举出来。

哈希里带上出价人地址。披露交易在内存池里是明文，别人即使看见金额和 `secret`，也完不成他自己名下的承诺。

提交期可以覆盖自己的承诺，第二次不再付保证金。卖家不能出价。

## 钱怎么走

| 人 | 结束时拿到 |
|---|---|
| 卖家 | 最高出价，加上没来披露的保证金 |
| 赢家 | 只退保证金 |
| 输家 | 退回出价和保证金 |
| 提交了但不披露 | 保证金没收，归卖家 |

保证金每个人相同，所以看不出谁出得更高。它的作用是：披露期已经能看见别人的价，弃标会亏掉这笔钱。构造参数传 `0` 表示不收保证金。

合约不主动转账。`withdraw()` 先把余额记到账上，再转出，避免退款时被重入。收款地址拒绝 ETH 时，这笔账还留在 `pendingReturns` 里。

## 文件

| 路径 | 作用 |
|---|---|
| `src/auction/SealedBidAuction.sol` | 拍卖合约 |
| `script/auction/DeploySealedBidAuction.s.sol` | 部署。提交期 1 小时，披露期 1 小时，保证金 0.01 ETH |
| `test/auction/SealedBidAuction.t.sol` | 测试 |

## 用法

```bash
forge test --match-path test/auction/SealedBidAuction.t.sol -vv

forge script script/auction/DeploySealedBidAuction.s.sol:DeploySealedBidAuction \
  --broadcast --rpc-url local \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  && cat ./deployments/LATEST.txt
```
