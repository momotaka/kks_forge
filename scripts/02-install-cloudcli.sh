#!/usr/bin/env bash
# CloudCLI を npx で初回取得し、npm キャッシュに乗せておく。
# systemd 起動時のコールドスタートでネットワーク失敗するのを避けるため。

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root
load_env

log "$FORGE_USER として ${FORGE_CLOUDCLI_PKG} を取得（初回ダウンロード）"
sudo -iu "$FORGE_USER" bash -lc "npx --yes ${FORGE_CLOUDCLI_PKG} --version || true"
ok "CloudCLI 取得完了（バージョン表示後すぐ抜けます）"
