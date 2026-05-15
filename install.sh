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
step_cloudcli() { bash scripts/02-install-cloudcli.sh; }
step_systemd()  { bash scripts/03-install-systemd.sh; }
step_nginx()    { bash scripts/04-install-nginx.sh; }
step_cert()     { bash scripts/05-issue-cert.sh; }
step_auth()     { bash scripts/06-setup-basic-auth.sh; }
step_memory()   { bash scripts/07-start-memory.sh; }
step_oauth() {
  forge_user="$(grep '^FORGE_USER=' .env | cut -d= -f2)"
  sudo -iu "$forge_user" claude setup-token
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
    run "env"       step_env
    run "bootstrap" step_bootstrap
    run "check"     step_check
    run "user"      step_user
    run "cloudcli"  step_cloudcli
    run "systemd"   step_systemd
    run "nginx"     step_nginx
    run "cert"      step_cert
    run "auth"      step_auth
    run "memory"    step_memory
    run "oauth"     step_oauth
    ;;
  env|bootstrap|check|user|cloudcli|systemd|nginx|cert|auth|memory|oauth|verify|status|logs)
    "step_$1"
    ;;
  *)
    echo "usage: $0 [install|env|bootstrap|check|user|cloudcli|systemd|nginx|cert|auth|memory|oauth|verify|status|logs]" >&2
    exit 2
    ;;
esac
