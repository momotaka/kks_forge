#!/usr/bin/env bash
# systemd unit を生成・配置して有効化する。

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env

src="${KKS_FORGE_ROOT}/systemd/kks-forge.service.tmpl"
dst="/etc/systemd/system/kks-forge.service"

log "systemd unit を生成: $dst"
render_template "$src" "$dst"
chmod 0644 "$dst"

log "daemon-reload & enable --now"
systemctl daemon-reload
systemctl enable --now kks-forge.service

sleep 2
systemctl --no-pager --full status kks-forge.service || true

ok "起動完了。ローカル確認:  curl -sS http://127.0.0.1:${FORGE_PORT}/ -o /dev/null -w '%{http_code}\\n'"
