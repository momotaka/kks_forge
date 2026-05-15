#!/usr/bin/env bash
# Basic 認証パスワードを設定する。
# - .htpasswd-forge を新規作成（既存があれば追記）
# - パスワードはこのスクリプト実行中に対話入力（履歴に残らない）

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env
require_cmd htpasswd

htpasswd_file="/etc/nginx/.htpasswd-forge"

if [[ -f "$htpasswd_file" ]] && grep -q "^${FORGE_BASIC_AUTH_USER}:" "$htpasswd_file"; then
  log "${FORGE_BASIC_AUTH_USER} のパスワードを再設定します"
  htpasswd "$htpasswd_file" "$FORGE_BASIC_AUTH_USER"
else
  log "${FORGE_BASIC_AUTH_USER} のパスワードを新規作成します"
  if [[ -f "$htpasswd_file" ]]; then
    htpasswd "$htpasswd_file" "$FORGE_BASIC_AUTH_USER"
  else
    htpasswd -c "$htpasswd_file" "$FORGE_BASIC_AUTH_USER"
  fi
fi
chmod 0640 "$htpasswd_file"
chown root:www-data "$htpasswd_file" 2>/dev/null || true

# nginx が起動していれば reload、停止中なら何もしない（起動時に自動で読まれる）
if systemctl is-active --quiet nginx; then
  systemctl reload nginx
  ok "Basic 認証設定完了 (nginx reload 済み)"
else
  warn "nginx が停止中なので reload はスキップ（起動時に反映されます）"
  ok "Basic 認証設定完了"
fi
