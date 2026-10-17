#!/usr/bin/env bash

# script/storage.sh \
#   src/wallet,lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol,lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol \
#   -c SocialRecoveryWallet

# 用 sol2uml 画出合约的存储槽分布。
# sol2uml 用 Node 解析 import，不读 Foundry remappings。
# 解析失败时临时建 openzeppelin-contracts 软链接，退出时删掉。
# 用法: script/storage.sh <sol2uml storage 的参数...>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODULES="$PROJECT_ROOT/node_modules"
LINK="$MODULES/openzeppelin-contracts"
TARGET="$PROJECT_ROOT/lib/openzeppelin-contracts"
OZ_IMPORT="openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol"

created_link=0
created_modules=0

usage() {
  cat <<'EOF'
用法: script/storage.sh <sol2uml storage 的参数...>

参数原样传给 `sol2uml storage`。常用的是源文件列表、合约名和输出位置。

  <文件或目录>   逗号分隔、中间不要空格。目录会递归收录其中的 .sol
  -c <合约名>    要画存储布局的合约
  -o <路径>      输出文件或目录。目录下文件名为 <合约名>.svg

脚本会检查 `openzeppelin-contracts/...` 能否被 Node 解析。
不能解析时，建立 node_modules/openzeppelin-contracts -> ../lib/openzeppelin-contracts。
这个软链接只在本次运行中存在，退出前删除。
若删完后 node_modules 里没有其他文件，node_modules 一并删除。

示例:
  script/storage.sh \
    src/wallet,lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol,lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol \
    -c SocialRecoveryWallet -o out
EOF
}

cleanup() {
  if [[ "$created_link" -eq 1 && -L "$LINK" ]]; then
    rm -f "$LINK"
  fi
  if [[ "$created_link" -eq 1 || "$created_modules" -eq 1 ]]; then
    if [[ -d "$MODULES" && -z "$(find "$MODULES" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      rmdir "$MODULES"
    fi
  fi
}

oz_resolves() {
  node -e "require.resolve(process.argv[1], {paths:[process.argv[2]]})" "$OZ_IMPORT" "$PROJECT_ROOT" >/dev/null 2>&1
}

ensure_oz_link() {
  if oz_resolves; then
    return 0
  fi
  if [[ ! -d "$TARGET" ]]; then
    echo "找不到 $TARGET，无法补上 openzeppelin-contracts 软链接。" >&2
    exit 1
  fi
  if [[ -e "$LINK" && ! -L "$LINK" ]]; then
    echo "$LINK 已存在且不是软链接，没有改动它。" >&2
    exit 1
  fi
  if [[ ! -d "$MODULES" ]]; then
    mkdir -p "$MODULES"
    created_modules=1
  fi
  ln -sfn ../lib/openzeppelin-contracts "$LINK"
  created_link=1
  if ! oz_resolves; then
    echo "已创建软链接，但仍然无法解析 $OZ_IMPORT。" >&2
    exit 1
  fi
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

cd "$PROJECT_ROOT"
trap cleanup EXIT
ensure_oz_link
npx --yes sol2uml storage "$@"
