#!/usr/bin/env bash
# mcp-memory-service を docker compose で起動する。
# - データディレクトリを準備
# - docker-compose.yml をテンプレから生成して /opt/kks-forge/memory に配置
# - docker compose up -d
# - 起動後、CloudCLI 側の MCP 管理画面で登録する手順を案内

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env
require_cmd docker

: "${FORGE_MEMORY_DATA_DIR:?FORGE_MEMORY_DATA_DIR を .env で設定してください}"
: "${FORGE_MEMORY_IMAGE:?FORGE_MEMORY_IMAGE を .env で設定してください}"

target_dir="/opt/kks-forge/memory"
src="${KKS_FORGE_ROOT}/memory/docker-compose.yml.tmpl"
dst="${target_dir}/docker-compose.yml"

install -d -m 0755 "$target_dir"
install -d -m 0755 "$FORGE_MEMORY_DATA_DIR"

log "docker-compose.yml を生成: $dst"
render_template "$src" "$dst"

log "docker compose pull"
(cd "$target_dir" && docker compose pull)

log "docker compose up -d"
(cd "$target_dir" && docker compose up -d)

ok "mcp-memory-service 起動。ログ:  docker logs -f kks-forge-memory"
log "次のステップ: CloudCLI の MCP 管理 UI で memory サーバーを追加してください"
