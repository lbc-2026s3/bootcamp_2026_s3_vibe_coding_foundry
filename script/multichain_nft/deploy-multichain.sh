#!/usr/bin/env bash
# 按链循环调用 forge script。每条链单独起一次进程，因为一次 forge script 只有一个 RPC。
#
# 默认只模拟，不广播：
#   script/multichain_nft/deploy-multichain.sh
#   NETWORKS=sepolia,bsc_testnet script/multichain_nft/deploy-multichain.sh
#
# 确认 RPC 和私钥后再广播：
#   BROADCAST=1 NETWORKS=sepolia script/multichain_nft/deploy-multichain.sh
#
# 网络名对应 foundry RPC 别名（.env 里的 FOUNDRY_RPC_ENDPOINTS，或临时环境变量）：
#   ethereum / mainnet -> mainnet (chainId 1)
#   polygon            -> polygon (137)
#   bsc                -> bsc (56)
#   arbitrum           -> arbitrum (42161)
#   sepolia            -> sepolia
#   bsc_testnet        -> bsc_testnet
#   local              -> local

set -euo pipefail

cd "$(dirname "$0")/../.."

NETWORKS="${NETWORKS:-local}"
IFS=',' read -r -a NETWORK_LIST <<< "$NETWORKS"

broadcast_args=()
if [[ "${BROADCAST:-}" == "1" ]]; then
  broadcast_args+=(--broadcast)
  if [[ -n "${PRIVATE_KEY:-}" ]]; then
    broadcast_args+=(--private-key "$PRIVATE_KEY")
  elif [[ "$NETWORKS" == "local" ]]; then
    # Anvil 默认账户 0。这是公开测试钥，只用于本地链。
    broadcast_args+=(--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
  else
    echo "BROADCAST=1 needs PRIVATE_KEY for non-local networks" >&2
    exit 1
  fi
fi

for network in "${NETWORK_LIST[@]}"; do
  network="$(echo "$network" | xargs)"
  [[ -z "$network" ]] && continue

  case "$network" in
    ethereum | mainnet) rpc=mainnet ;;
    polygon) rpc=polygon ;;
    bsc) rpc=bsc ;;
    arbitrum) rpc=arbitrum ;;
    sepolia) rpc=sepolia ;;
    bsc_testnet | bsc-testnet) rpc=bsc_testnet ;;
    local | anvil | anvil1) rpc=local ;;
    *)
      echo "Unsupported network: $network" >&2
      echo "Use ethereum, polygon, bsc, arbitrum, sepolia, bsc_testnet, or local." >&2
      exit 1
      ;;
  esac

  echo "Deploying UniversalNFTCollection via --rpc-url $rpc"
  if [[ ${#broadcast_args[@]} -eq 0 ]]; then
    forge script script/multichain_nft/DeployUniversalNFT.s.sol:DeployUniversalNFT --rpc-url "$rpc"
  else
    forge script script/multichain_nft/DeployUniversalNFT.s.sol:DeployUniversalNFT \
      --rpc-url "$rpc" \
      "${broadcast_args[@]}"
  fi
done

if [[ "${BROADCAST:-}" == "1" ]]; then
  python3 - <<'PY'
import json
from pathlib import Path

root = Path("deployments")
rows = []
for path in sorted(root.glob("UniversalNFTCollection/UniversalNFTCollection_*.json")):
    data = json.loads(path.read_text())
    chain_id = str(data.get("chainId"))
    impl = root / "UniversalNFTCollection_Implementation" / f"UniversalNFTCollection_Implementation_{chain_id}.json"
    admin = root / "UniversalNFTCollection_ProxyAdmin" / f"UniversalNFTCollection_ProxyAdmin_{chain_id}.json"
    rows.append(
        {
            "chainId": data.get("chainId"),
            "proxy": data.get("address"),
            "implementation": json.loads(impl.read_text()).get("address") if impl.exists() else None,
            "proxyAdmin": json.loads(admin.read_text()).get("address") if admin.exists() else None,
            "deployer": data.get("deployer"),
            "deployedAt": data.get("deployedAt"),
        }
    )
out = root / "multi-chain-summary.json"
out.write_text(json.dumps(rows, indent=2) + "\n")
print(f"Wrote {out} ({len(rows)} chain(s))")
PY
fi
