#!/usr/bin/env bash
# 合约验证脚本：调用 forge verify-contract 在 Etherscan 上验证已部署合约源码
# 用法: script/verify.sh <合约路径> <部署地址> [选项]，详见 --help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载 .env（ETHERSCAN_API_KEY、FOUNDRY_RPC_ENDPOINTS 等）
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/.env"
  set +a
fi

usage() {
  cat <<'EOF'
用法: script/verify.sh <合约路径> <部署地址> [选项]

  合约路径   如 src/TokenBankV1.sol:TokenBankV1
  部署地址   已部署的合约地址（0x...）

选项:
  --constructor <类型[,类型...]> <值[,值...]>
              构造参数，类型与值均为逗号分隔，脚本用 cast abi-encode 编码
              例: --constructor address 0x8b0F9023d0a917503Cd247bD9985B6527E4fA846
  --args-hex <0x...>
              直接传入已 ABI 编码的构造参数（跳过编码，适合数组等复杂参数）
  --chain <链名>    目标链，默认 sepolia
  --no-watch        提交后不等待验证结果
  -h, --help        显示帮助

环境变量（脚本已自动 source .env）:
  ETHERSCAN_API_KEY  Etherscan API key
  CHAIN              默认链（等价于 --chain）

示例:
  script/verify.sh src/Counter.sol:Counter 0x1234...
  script/verify.sh src/TokenBankV1.sol:TokenBankV1 0x1234... \
      --constructor address 0x8b0F9023d0a917503Cd247bD9985B6527E4fA846
EOF
}

# ---------- 参数解析 ----------
CONSTRUCTOR_HEX=""
CHAIN="${CHAIN:-sepolia}"
WATCH_FLAG="--watch"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --constructor)
      [[ $# -ge 3 ]] || { echo "错误: --constructor 需要 <类型列表> <值列表>" >&2; exit 1; }
      TYPES="$2"
      VALUES="$3"
      shift 3
      IFS=',' read -r -a TYPE_ARR <<< "$TYPES"
      IFS=',' read -r -a VALUE_ARR <<< "$VALUES"
      [[ ${#TYPE_ARR[@]} -eq ${#VALUE_ARR[@]} ]] || {
        echo "错误: 构造参数类型数量 (${#TYPE_ARR[@]}) 与值数量 (${#VALUE_ARR[@]}) 不一致" >&2
        exit 1
      }
      CONSTRUCTOR_HEX="$(cast abi-encode "constructor($TYPES)" "${VALUE_ARR[@]}")"
      ;;
    --args-hex)
      [[ $# -ge 2 ]] || { echo "错误: --args-hex 需要十六进制参数" >&2; exit 1; }
      CONSTRUCTOR_HEX="$2"
      shift 2
      ;;
    --chain)
      [[ $# -ge 2 ]] || { echo "错误: --chain 需要链名" >&2; exit 1; }
      CHAIN="$2"
      shift 2
      ;;
    --no-watch)
      WATCH_FLAG=""
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

[[ ${#POSITIONAL[@]} -ge 2 ]] || { usage >&2; exit 1; }
CONTRACT="${POSITIONAL[0]}"
ADDRESS="${POSITIONAL[1]}"

# ---------- 环境检查 ----------
: "${ETHERSCAN_API_KEY:?缺少 ETHERSCAN_API_KEY，请检查 .env}"

# ---------- 执行验证 ----------
CMD=(forge verify-contract "$ADDRESS" "$CONTRACT" --chain "$CHAIN" --etherscan-api-key "$ETHERSCAN_API_KEY")
[[ -n "$CONSTRUCTOR_HEX" ]] && CMD+=(--constructor-args "$CONSTRUCTOR_HEX")
[[ -n "$WATCH_FLAG" ]] && CMD+=("$WATCH_FLAG")

echo "验证合约: $CONTRACT @ $ADDRESS (chain: $CHAIN)"
if [[ -n "$CONSTRUCTOR_HEX" ]]; then
  echo "构造参数: $CONSTRUCTOR_HEX"
fi
"${CMD[@]}"
