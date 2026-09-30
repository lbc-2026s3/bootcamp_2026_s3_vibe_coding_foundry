# VotingToken

基于 OpenZeppelin `ERC20` + `ERC20Permit` + `ERC20Votes` 的可投票治理代币。

## 核心行为

| 能力 | 说明 |
|------|------|
| 转账 | 标准 ERC20 |
| Permit | ERC-2612 离线授权 |
| 投票权 | 余额 **不会自动算票**；需 `delegate(自己或他人)` |
| 历史票权 | `getPastVotes(account, blockNumber)` / `getPastTotalSupply` |
| 增发 | `owner` 可 `mint` |

## 常用调用

```solidity
// 激活自己的票权
token.delegate(msg.sender);

// 当前票权 / 某历史区块结束时的票权
token.getVotes(account);
token.getPastVotes(account, blockNumber); // blockNumber < block.number

// 查询委托关系
token.delegates(account);
```

## 测试 / 部署

```bash
forge test --match-path test/voting/VotingToken.t.sol -vv

forge script script/voting/DeployVotingToken.s.sol:DeployVotingToken \
  --broadcast --rpc-url local \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  && cat ./deployments/LATEST.txt
```

可与 OpenZeppelin `Governor` + `GovernorVotes` 组合构成完整链上治理。
