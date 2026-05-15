#!/usr/bin/env bash
# Nginx 設定を配置する。
# - sites-available/forge.conf を生成 → sites-enabled に symlink
# - snippets/kks-forge-allow.conf に allow/deny を書く
# - 既存設定を壊さないため nginx -t で検証してから reload

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env

require_cmd nginx

src="${KKS_FORGE_ROOT}/nginx/forge.conf.tmpl"
dst="/etc/nginx/sites-available/${FORGE_DOMAIN}.conf"
link="/etc/nginx/sites-enabled/${FORGE_DOMAIN}.conf"
allow_snippet="/etc/nginx/snippets/kks-forge-allow.conf"

log "Nginx site 設定を生成: $dst"
render_template "$src" "$dst"
chmod 0644 "$dst"

# 許可 IP スニペット
mkdir -p /etc/nginx/snippets
if [[ "${FORGE_ALLOW_ALL:-0}" == "1" || -z "${FORGE_ALLOW_IPS:-}" ]]; then
  log "IP 制限なしで生成（Basic 認証のみ）"
  : > "$allow_snippet"
else
  log "IP 制限を生成: ${FORGE_ALLOW_IPS}"
  {
    IFS=',' read -ra ips <<< "$FORGE_ALLOW_IPS"
    for ip in "${ips[@]}"; do
      ip_trimmed="$(echo "$ip" | xargs)"
      [[ -n "$ip_trimmed" ]] && echo "allow ${ip_trimmed};"
    done
    echo "deny all;"
  } > "$allow_snippet"
fi
chmod 0644 "$allow_snippet"

# sites-enabled に有効化
ln -sf "$dst" "$link"

# nginx -t を通してから reload
log "nginx -t で検証"
if ! nginx -t; then
  die "Nginx 設定検証に失敗。$dst を見直してください。"
fi
systemctl reload nginx
ok "Nginx 再読込完了"
