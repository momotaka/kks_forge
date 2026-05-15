#!/usr/bin/env bash
# 共通ライブラリ。各 scripts/*.sh から `source` される。
# - .env を読み込み、変数を export する
# - ログ・エラー処理ヘルパを提供する
# - root 権限チェックを提供する

set -euo pipefail

# このファイルがある scripts/lib から見た repo root
KKS_FORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export KKS_FORGE_ROOT

# 色付きログ（端末以外では無色）
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_BOLD='\033[1m'
  C_RED='\033[31m'; C_GREEN='\033[32m'; C_YELLOW='\033[33m'; C_CYAN='\033[36m'
else
  C_RESET=''; C_BOLD=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_CYAN=''
fi

log()  { printf "${C_CYAN}[KKS-Forge]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_GREEN}[OK]${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$*" >&2; }
die()  { printf "${C_RED}[ERROR]${C_RESET} %s\n" "$*" >&2; exit 1; }

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    die "このスクリプトは root で実行してください (sudo make ... 等)"
  fi
}

require_cmd() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd が見つかりません。先にインストールしてください。"
  done
}

# .env を読み込む。なければ .env.example を案内して終了。
load_env() {
  local env_file="${KKS_FORGE_ROOT}/.env"
  if [[ ! -f "$env_file" ]]; then
    die ".env が見つかりません。\`cp .env.example .env\` で作成して編集してください。"
  fi
  # `set -a` で読み込み中に export を有効化
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a

  : "${FORGE_DOMAIN:?FORGE_DOMAIN を .env で設定してください}"
  : "${FORGE_USER:?FORGE_USER を .env で設定してください}"
  : "${FORGE_HOME:?FORGE_HOME を .env で設定してください}"
  : "${FORGE_PORT:?FORGE_PORT を .env で設定してください}"
}

# テンプレートを envsubst でレンダリングする。
# 使い方: render_template <input.tmpl> <output>
render_template() {
  local src="$1"
  local dst="$2"
  [[ -f "$src" ]] || die "テンプレが見つかりません: $src"
  require_cmd envsubst
  mkdir -p "$(dirname "$dst")"
  # 置換対象を明示（環境変数の汚染防止）
  envsubst '${FORGE_DOMAIN} ${FORGE_USER} ${FORGE_HOME} ${FORGE_PORT} ${FORGE_CLOUDCLI_PKG} ${FORGE_LOG_DIR} ${FORGE_MEMORY_DATA_DIR} ${FORGE_MEMORY_IMAGE} ${FORGE_BASIC_AUTH_USER}' \
    < "$src" > "$dst"
}
