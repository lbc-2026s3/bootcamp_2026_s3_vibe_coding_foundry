#!/usr/bin/env bash
# 拉取一笔交易的收据日志，按输出顺序把每条 log 的 topics 和 data 拼起来，
# 再交给 cast decode-event 解码。
# 用法: script/decode-receipt-logs.sh <tx_hash> [--rpc-url sepolia]
set -euo pipefail

RPC_URL="sepolia"
TX_HASH=""

usage() {
  cat <<'EOF'
用法: script/decode-receipt-logs.sh <tx_hash> [--rpc-url <url>]

按 cast receipt <tx> logs 的数组顺序处理每条日志：
  1. 依次取 topics[0..] 和 data
  2. 去掉各段的 0x 前缀后拼接（data 为 "0x" 时没有字节，不拼进去）
  3. 把拼好的 0x... 传给 cast decode-event

  tx_hash          交易哈希，必填
  --rpc-url <url>  RPC 端点，默认 sepolia

示例:
  script/decode-receipt-logs.sh 0xb00219492d0e078afb3982ebb2ef9348ddc4ad4f4b8c9783159997c4dd95e727 --rpc-url sepolia
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --rpc-url)
      [[ $# -ge 2 ]] || { echo "错误: --rpc-url 需要一个端点" >&2; exit 1; }
      RPC_URL="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "未知选项: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$TX_HASH" ]]; then
        echo "错误: 只能传一个交易哈希" >&2
        exit 1
      fi
      TX_HASH="$1"
      shift
      ;;
  esac
done

if [[ -z "$TX_HASH" ]]; then
  echo "错误: 缺少交易哈希" >&2
  usage >&2
  exit 1
fi

command -v cast >/dev/null || { echo "找不到 cast" >&2; exit 1; }
command -v jq >/dev/null || { echo "找不到 jq" >&2; exit 1; }

logs_json="$(cast receipt "$TX_HASH" logs --rpc-url "$RPC_URL")"

if ! printf '%s' "$logs_json" | jq -e 'type == "array"' >/dev/null; then
  echo "cast receipt logs 的输出不是 JSON 数组:" >&2
  printf '%s\n' "$logs_json" >&2
  exit 1
fi

log_count="$(printf '%s' "$logs_json" | jq 'length')"
if [[ "$log_count" -eq 0 ]]; then
  echo "交易 $TX_HASH 没有事件日志"
  exit 0
fi

echo "tx: $TX_HASH"
echo "logs: $log_count"
echo

index=0
while IFS=$'\t' read -r address log_index payload; do
  index=$((index + 1))
  echo "[$index] address=$address logIndex=$log_index"
  echo "payload=0x$payload"
  if ! decoded="$(cast decode-event "0x$payload" 2>&1)"; then
    echo "decode-event 失败:"
    printf '%s\n' "$decoded"
  else
    printf '%s\n' "$decoded"
  fi
  echo
done < <(
  printf '%s' "$logs_json" | jq -r '
    .[] |
    [
      .address,
      .logIndex,
      (
        ([.topics[], .data] // [])
        | map(select(. != null and . != "0x" and . != ""))
        | map(ltrimstr("0x"))
        | join("")
      )
    ]
    | @tsv
  '
)
