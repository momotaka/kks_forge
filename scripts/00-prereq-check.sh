#!/usr/bin/env bash
# 前提条件チェック。
# - root 権限
# - Node.js v22 以上
# - npx
# - nginx, certbot, docker, docker compose, envsubst, openssl
# 不足は教えるだけで、自動インストールはしない（VPS の構成を勝手に変えないため）。

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env

missing=()

check_cmd() {
  local cmd="$1" hint="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd: $(command -v "$cmd")"
  else
    warn "$cmd が無い → $hint"
    missing+=("$cmd")
  fi
}

log "コマンド検査"
check_cmd node    "nvm or apt で Node.js v22+ を入れてください"
check_cmd npx     "Node.js に同梱されているはず"
check_cmd nginx   "apt install nginx"
check_cmd certbot "apt install certbot python3-certbot-nginx"
check_cmd docker  "https://docs.docker.com/engine/install/ に従って導入"
check_cmd envsubst "apt install gettext-base"
check_cmd openssl "apt install openssl"
check_cmd htpasswd "apt install apache2-utils"

# docker compose は v2 サブコマンド
if docker compose version >/dev/null 2>&1; then
  ok "docker compose: $(docker compose version | head -n1)"
else
  warn "docker compose (v2) が無い → docker-compose-plugin を導入してください"
  missing+=("docker-compose-plugin")
fi

# Node.js のバージョンが 22 以上か
if command -v node >/dev/null 2>&1; then
  ver="$(node -p 'process.versions.node')"
  major="${ver%%.*}"
  if [[ "$major" -lt 22 ]]; then
    warn "Node.js は $ver ですが、CloudCLI は v22 以上を要求します"
    missing+=("node>=22")
  else
    ok "Node.js バージョン OK ($ver)"
  fi
fi

# ポート競合チェック
if ss -ltn "sport = :${FORGE_PORT}" 2>/dev/null | tail -n +2 | grep -q .; then
  warn "ポート ${FORGE_PORT} が既に使われています:"
  ss -ltn "sport = :${FORGE_PORT}" | sed 's/^/    /'
  missing+=("port:${FORGE_PORT}")
else
  ok "ポート ${FORGE_PORT} は空いています"
fi

if [[ ${#missing[@]} -gt 0 ]]; then
  die "不足: ${missing[*]}  ← 解決してから再実行してください"
fi
ok "前提条件 OK"
