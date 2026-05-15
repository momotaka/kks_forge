#!/usr/bin/env bash
# CloudCLI のポート (${FORGE_PORT}) を外部から直接叩けないようにする。
# - ufw があれば ufw deny で。なければ警告だけ出して exit 0。
# - Nginx (80/443) は明示的に allow。
# - 既存の他サイト用ポートには手を出さない。

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env

if ! command -v ufw >/dev/null 2>&1; then
  warn "ufw が見つかりません。iptables / nftables で外部からの :${FORGE_PORT} を遮断してください。"
  exit 0
fi

# ufw 自体が無効なら触らない（既存環境を壊さない）
if ! ufw status | grep -q "Status: active"; then
  warn "ufw が無効です。有効化してから ufw deny ${FORGE_PORT}/tcp を実行してください。"
  exit 0
fi

log "ufw で :${FORGE_PORT}/tcp を外部から遮断"
ufw deny "${FORGE_PORT}/tcp" || true
log "ufw で 80/tcp, 443/tcp を許可"
ufw allow 80/tcp  || true
ufw allow 443/tcp || true

ok "ファイアウォール設定完了"
ufw status verbose | head -30 || true
