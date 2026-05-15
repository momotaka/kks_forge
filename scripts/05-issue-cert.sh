#!/usr/bin/env bash
# Let's Encrypt 証明書を取得し、Nginx を再読込する。
# 既に証明書がある場合は更新フックの確認だけ行う。

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env
require_cmd certbot

cert_path="/etc/letsencrypt/live/${FORGE_DOMAIN}/fullchain.pem"

if [[ -f "$cert_path" ]]; then
  ok "既存の証明書を検出: $cert_path"
  log "certbot renew --dry-run で更新フローを点検"
  certbot renew --dry-run
  exit 0
fi

: "${FORGE_LE_EMAIL:?FORGE_LE_EMAIL を .env で設定してください}"

log "certbot で証明書を新規発行: ${FORGE_DOMAIN}"
# nginx プラグインを使うと自動で sites の SSL を有効化してくれるが、
# 我々の設定は既に listen 443 ssl 済みなので --webroot で取りに行く。
mkdir -p /var/www/html
certbot certonly \
  --webroot -w /var/www/html \
  --non-interactive --agree-tos \
  --email "${FORGE_LE_EMAIL}" \
  -d "${FORGE_DOMAIN}"

systemctl reload nginx
ok "証明書発行完了。https://${FORGE_DOMAIN}/ で確認できます。"
