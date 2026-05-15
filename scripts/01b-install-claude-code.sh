#!/usr/bin/env bash
# forge ユーザー用に Claude Code をインストールする。
# 公式インストーラ (curl | sh) を使い、~/.local/bin/claude に置く。
# 既に入っていればスキップ。

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env

if sudo -iu "$FORGE_USER" bash -lc 'command -v claude' >/dev/null 2>&1; then
  current="$(sudo -iu "$FORGE_USER" bash -lc 'command -v claude')"
  ok "Claude Code は既にあります ($FORGE_USER): $current"
  exit 0
fi

log "$FORGE_USER ユーザーで Claude Code 公式インストーラを実行"
# Anthropic 公式: https://claude.ai/install.sh → ~/.local/bin/claude
sudo -iu "$FORGE_USER" bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'

# 確認
if installed="$(sudo -iu "$FORGE_USER" bash -lc 'command -v claude' 2>/dev/null)"; then
  ok "Claude Code 導入完了: $installed"
else
  die "Claude Code のインストールに失敗。手動で curl -fsSL https://claude.ai/install.sh | bash を試してください。"
fi
