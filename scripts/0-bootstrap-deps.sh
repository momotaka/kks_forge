#!/usr/bin/env bash
# 不足している apt パッケージと Node.js v22+ を自動でインストールする。
# - install.sh / Makefile の install チェーン先頭で呼ばれる
# - Debian/Ubuntu 専用
# - 既に入っているものは触らない
# - 環境変数 FORGE_SKIP_BOOTSTRAP=1 なら何もしない（手動管理派向け）

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_root

if [[ "${FORGE_SKIP_BOOTSTRAP:-0}" == "1" ]]; then
  ok "FORGE_SKIP_BOOTSTRAP=1 のため依存導入をスキップ"
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  warn "apt-get が無いため自動導入をスキップ（Debian/Ubuntu 専用）"
  exit 0
fi

apt_updated=0
ensure_apt_update() {
  if [[ "$apt_updated" -eq 0 ]]; then
    log "apt-get update"
    DEBIAN_FRONTEND=noninteractive apt-get update -y
    apt_updated=1
  fi
}

# パッケージ単位で「コマンドが無ければ apt で入れる」
ensure_pkg() {
  local cmd="$1" pkg="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd: 既にあり"
  else
    log "$cmd → apt install $pkg"
    ensure_apt_update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
  fi
}

ensure_pkg nginx     nginx
ensure_pkg certbot   certbot
ensure_pkg envsubst  gettext-base
ensure_pkg openssl   openssl
ensure_pkg htpasswd  apache2-utils
ensure_pkg curl      curl
ensure_pkg git       git
ensure_pkg make      make

# --- Docker (公式の get-docker.sh を使う。簡素で安定) ---
if command -v docker >/dev/null 2>&1; then
  ok "docker: 既にあり"
else
  log "docker → get-docker.sh で導入"
  curl -fsSL https://get.docker.com | sh
fi

# docker compose v2 サブコマンドの確認
if docker compose version >/dev/null 2>&1; then
  ok "docker compose: 既にあり"
else
  log "docker-compose-plugin を導入"
  ensure_apt_update
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin || \
    warn "docker-compose-plugin の導入に失敗。get-docker.sh で入った plugin を確認してください。"
fi

# --- Node.js v22+ (NodeSource) ---
need_node=1
if command -v node >/dev/null 2>&1; then
  ver="$(node -p 'process.versions.node' 2>/dev/null || echo 0)"
  major="${ver%%.*}"
  if [[ "${major:-0}" -ge 22 ]]; then
    ok "node: v$ver"
    need_node=0
  else
    warn "node は v$ver。v22+ が必要なので入れ替えます。"
  fi
fi

if [[ "$need_node" -eq 1 ]]; then
  log "Node.js v22 を NodeSource から導入"
  ensure_apt_update
  DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
fi

# certbot の nginx プラグインは webroot 取得なら不要だが、あれば便利
DEBIAN_FRONTEND=noninteractive apt-get install -y python3-certbot-nginx >/dev/null 2>&1 || true

ok "依存パッケージ準備完了"
