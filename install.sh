#!/usr/bin/env bash
# make が無い VPS でも動くブートストラップ。
# 内容は Makefile の install ターゲットと等価。
#
# 使い方:
#   sudo ./install.sh          # 全自動セットアップ (Phase 1〜3 + OAuth)
#   sudo ./install.sh env      # 個別ステップ実行も可
#   sudo ./install.sh memory
#
# 引数なしの場合は、make install と同じ順番で全部を順次実行する。

set -euo pipefail

cd "$(dirname "$0")"

# make が入っていれば、そっち（Makefile）に委譲して終了
if command -v make >/dev/null 2>&1; then
  exec make "${@:-install}"
fi

# --- make なしフォールバック ---------------------------------------------------
echo "[install.sh] make が見つからないので、シェル版で実行します"
echo "             apt install -y make を入れると Makefile が使えます"

run() {
  echo
  echo "==> $1"
  shift
  "$@"
}

step_env()      { bash scripts/0-prepare-env.sh; }
step_bootstrap(){ bash scripts/0-bootstrap-deps.sh; }
step_check()    { bash scripts/00-prereq-check.sh; }
step_user()     { bash scripts/01-create-user.sh; }
step_claude()   { bash scripts/01b-install-claude-code.sh; }
step_cloudcli() { bash scripts/02-install-cloudcli.sh; }
step_systemd()  { bash scripts/03-install-systemd.sh; }
step_firewall() { bash scripts/03b-firewall-lockdown.sh; }
step_nginx()    { bash scripts/04-install-nginx.sh; }
step_cert()     { bash scripts/05-issue-cert.sh; }
step_auth()     { bash scripts/06-setup-basic-auth.sh; }
step_memory()   { bash scripts/07-start-memory.sh; }
step_oauth() {
  # KKS-Forge は Pro/Max サブスク前提なので、`claude setup-token` (長期 API トークン
  # 発行) は使わない。CloudCLI を開いた状態で `claude /login` を回す方が安全
  # （トークンが標準出力に出ない、~/.claude/credentials.json に保存される）。
  forge_user="$(grep '^FORGE_USER=' .env | cut -d= -f2)"
  cat <<EOS

==================================================================
  Claude Code 認証は手動で行ってください（標準出力にトークンを残さないため）

  方法 1: CloudCLI の UI で行う（推奨）
    1. ブラウザで https://forge.kkshd.jp/ を開く
    2. 新規セッションを作成して何か発言する
    3. CloudCLI が認証プロンプトを案内するのでそれに従う

  方法 2: forge ユーザーのシェルで対話ログイン
    sudo -iu ${forge_user}
    claude   # 起動後 /login を実行 → ブラウザで OAuth 承認
    exit

  ⚠ \`claude setup-token\` は使わないでください。
     表示される長期トークンが履歴/ログに残ると漏洩リスクになります。
     Pro/Max サブスクの場合は不要です。
==================================================================
EOS
}
step_verify() {
  # shellcheck disable=SC1091
  set -a; source .env; set +a
  echo "→ local CloudCLI:"
  curl -sS -o /dev/null -w '  http://127.0.0.1:'"$FORGE_PORT"'/  %{http_code}\n' "http://127.0.0.1:$FORGE_PORT/" || true
  echo "→ public HTTPS:"
  curl -ksS -o /dev/null -w '  https://'"$FORGE_DOMAIN"'/  %{http_code}\n' "https://$FORGE_DOMAIN/" || true
  echo "→ memory container:"
  docker ps --filter name=kks-forge-memory --format '  {{.Names}}  {{.Status}}' || true
}
step_status() { systemctl --no-pager --full status kks-forge.service || true; }
step_logs()   { journalctl -u kks-forge.service -f; }

case "${1:-install}" in
  install)
    run "env"            step_env
    run "bootstrap"      step_bootstrap
    run "check"          step_check
    run "user"           step_user
    run "claude"         step_claude
    run "cloudcli"       step_cloudcli
    run "systemd"        step_systemd
    run "firewall"       step_firewall  # CloudCLI ポートを外部から遮断
    run "nginx (http)"   step_nginx     # HTTP-only で立ち上げる
    run "cert"           step_cert      # webroot で証明書取得
    run "nginx (https)"  step_nginx     # 証明書を読み込んで HTTPS フル設定に差し替え
    run "auth"           step_auth
    run "memory"         step_memory
    run "oauth"          step_oauth
    ;;
  env|bootstrap|check|user|claude|cloudcli|systemd|firewall|nginx|cert|auth|memory|oauth|verify|status|logs)
    "step_$1"
    ;;
  *)
    echo "usage: $0 [install|env|bootstrap|check|user|claude|cloudcli|systemd|firewall|nginx|cert|auth|memory|oauth|verify|status|logs]" >&2
    exit 2
    ;;
esac
