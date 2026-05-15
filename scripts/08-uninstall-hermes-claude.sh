#!/usr/bin/env bash
# Hermes コンテナ内の Claude Code を撤去する（Phase 5 / 残課題 8.4）
# - 「Hermes に開発を振ってしまう事故」を物理的に防ぐ
# - コンテナ名は固定ではないので、対話で確認しながら進める

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env

if ! command -v docker >/dev/null 2>&1; then
  warn "docker が無いのでスキップ"
  exit 0
fi

# Hermes 関連コンテナを列挙
mapfile -t containers < <(docker ps -a --format '{{.Names}}' | grep -Ei 'hermes' || true)

if [[ ${#containers[@]} -eq 0 ]]; then
  ok "Hermes コンテナは見つかりませんでした。何もすることはありません。"
  exit 0
fi

log "Hermes 関連コンテナが見つかりました:"
printf '  - %s\n' "${containers[@]}"

cat <<EOS

これから各コンテナ内の Claude Code を削除します。
コンテナ自体は残します（Hermes 本体は維持）。
よろしければ Enter、中止したければ Ctrl+C を押してください。
EOS
read -r _

for c in "${containers[@]}"; do
  log "[$c] claude バイナリの場所を探す"
  if path="$(docker exec "$c" sh -c 'command -v claude || true' 2>/dev/null)"; then
    if [[ -n "$path" ]]; then
      log "[$c] 削除対象: $path"
      docker exec "$c" sh -c "rm -f '$path' && rm -rf ~/.claude/projects/* 2>/dev/null || true"
      ok "[$c] 削除完了"
    else
      ok "[$c] Claude Code は既に入っていません"
    fi
  fi
done

ok "Hermes 側 Claude Code 撤去完了"
