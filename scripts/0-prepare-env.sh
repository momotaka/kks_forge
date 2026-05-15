#!/usr/bin/env bash
# .env を準備する。
# - 無ければ .env.example からコピー
# - $EDITOR (or sensible-editor / nano / vi) で開いて編集させる
# - 必須変数が初期値のままなら警告

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

env_file="${KKS_FORGE_ROOT}/.env"
example_file="${KKS_FORGE_ROOT}/.env.example"

# 既存なら触らずに開くだけ（再編集も許可）
if [[ ! -f "$env_file" ]]; then
  [[ -f "$example_file" ]] || die ".env.example が見つかりません: $example_file"
  cp "$example_file" "$env_file"
  ok ".env を新規作成しました（.env.example をコピー）"
else
  log ".env は既に存在します。再編集します。"
fi

# 編集に使うコマンドを決める
editor="${EDITOR:-}"
if [[ -z "$editor" ]]; then
  if   command -v sensible-editor >/dev/null 2>&1; then editor=sensible-editor
  elif command -v nano            >/dev/null 2>&1; then editor=nano
  elif command -v vim             >/dev/null 2>&1; then editor=vim
  elif command -v vi              >/dev/null 2>&1; then editor=vi
  else die "エディタが見つかりません。EDITOR=... を export して再実行してください。"
  fi
fi

log "$editor で .env を開きます。編集して保存・終了するとインストールが続行されます。"
"$editor" "$env_file"

# 編集後の中身を簡易検証
set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

problems=()
[[ -z "${FORGE_DOMAIN:-}"   || "$FORGE_DOMAIN"   == "forge.kkshd.jp" ]] && problems+=("FORGE_DOMAIN がサンプル値のままです（必要なら確認）")
[[ -z "${FORGE_LE_EMAIL:-}" || "$FORGE_LE_EMAIL" == "admin@kkshd.jp" ]] && problems+=("FORGE_LE_EMAIL がサンプル値のままです（Let's Encrypt 通知先）")

if (( ${#problems[@]} > 0 )); then
  warn "以下は要確認:"
  for p in "${problems[@]}"; do warn "  - $p"; done
  warn "意図したものであれば無視して構いません。"
fi

ok ".env 準備完了: $env_file"
