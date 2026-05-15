#!/usr/bin/env bash
# Claude Code の hooks から呼ぶ、薄い Telegram 通知ブリッジ。
#
# 使い方:
#   FORGE_TELEGRAM_BOT_TOKEN と FORGE_TELEGRAM_CHAT_ID を .env か環境変数で設定し、
#   ~/.claude/settings.json の hooks（Stop / SubagentStop など）で本スクリプトを呼ぶ。
#
# Claude Code hooks の JSON が stdin に流れてくるので、event 種別と要約を取り出して送る。

set -euo pipefail

# .env を辿って読み込む（CLAUDE_PROJECT_DIR か実行 cwd を起点に上に向かう）
load_env_walk() {
  local start="${CLAUDE_PROJECT_DIR:-$PWD}"
  local dir="$start"
  for _ in 1 2 3 4 5 6; do
    if [[ -f "$dir/.env" ]]; then
      # shellcheck disable=SC1091
      set -a; source "$dir/.env"; set +a
      return 0
    fi
    [[ "$dir" == "/" ]] && break
    dir="$(dirname "$dir")"
  done
}
load_env_walk

[[ -n "${FORGE_TELEGRAM_BOT_TOKEN:-}" ]] || { echo "telegram bot token 未設定" >&2; exit 0; }
[[ -n "${FORGE_TELEGRAM_CHAT_ID:-}" ]]   || { echo "telegram chat id 未設定"   >&2; exit 0; }

payload="$(cat || true)"
event="${1:-event}"
host="$(hostname -s 2>/dev/null || echo host)"

# JSON 本文の先頭 400 文字だけ拾う（プライバシー配慮）
short="$(printf '%s' "$payload" | tr -d '\r' | head -c 400)"
[[ -z "$short" ]] && short="(no payload)"

text="🔨 KKS-Forge / ${event} / ${host}
\`\`\`
${short}
\`\`\`"

curl -sS -o /dev/null \
  --data-urlencode "chat_id=${FORGE_TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${text}" \
  --data-urlencode "parse_mode=Markdown" \
  "https://api.telegram.org/bot${FORGE_TELEGRAM_BOT_TOKEN}/sendMessage" || true
