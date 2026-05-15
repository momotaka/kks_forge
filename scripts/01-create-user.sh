#!/usr/bin/env bash
# 専用ユーザー ${FORGE_USER} を作成する（既にあれば何もしない）。
# - ホームディレクトリ ${FORGE_HOME} を作る
# - .claude / projects ディレクトリを掘っておく
# - ログディレクトリ ${FORGE_LOG_DIR} を作って所有権を渡す

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env

if id -u "$FORGE_USER" >/dev/null 2>&1; then
  ok "ユーザー $FORGE_USER は既に存在"
else
  log "ユーザー $FORGE_USER を作成"
  useradd -m -d "$FORGE_HOME" -s /bin/bash "$FORGE_USER"
  ok "作成完了"
fi

install -d -o "$FORGE_USER" -g "$FORGE_USER" -m 0755 \
  "$FORGE_HOME/.claude" \
  "$FORGE_HOME/.claude/projects" \
  "$FORGE_HOME/projects"

install -d -o "$FORGE_USER" -g "$FORGE_USER" -m 0755 "${FORGE_LOG_DIR:-/var/log/kks-forge}"

ok "ホーム配置完了: $FORGE_HOME"
log "次のステップ:  sudo -iu $FORGE_USER  で入って  'claude setup-token'  を実行してください"
