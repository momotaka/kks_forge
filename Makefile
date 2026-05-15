.PHONY: help env check user cloudcli systemd nginx cert auth memory install verify status logs uninstall-hermes

SHELL := /bin/bash

help: ## このヘルプを表示
	@awk 'BEGIN {FS=":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

env: ## .env を .env.example から作る（既にあればスキップ）
	@if [ -f .env ]; then echo ".env は既にあります"; else cp .env.example .env && echo ".env を作りました。編集してください。"; fi

# ==== Phase 1: 最小動作版 ====
check: ## 前提条件チェック
	sudo bash scripts/00-prereq-check.sh

user: ## forge ユーザー作成
	sudo bash scripts/01-create-user.sh

cloudcli: ## CloudCLI を初回 npx 取得（systemd 起動前にキャッシュ）
	sudo bash scripts/02-install-cloudcli.sh

# ==== Phase 2: 永続化と公開 ====
systemd: ## systemd unit 配置 & 起動
	sudo bash scripts/03-install-systemd.sh

nginx: ## Nginx 設定 (要: certbot 後)
	sudo bash scripts/04-install-nginx.sh

cert: ## Let's Encrypt 証明書取得
	sudo bash scripts/05-issue-cert.sh

auth: ## Basic 認証パスワード設定
	sudo bash scripts/06-setup-basic-auth.sh

# ==== Phase 3: 記憶統合 ====
memory: ## mcp-memory-service を Docker で起動
	sudo bash scripts/07-start-memory.sh

# ==== Phase 5: Hermes 撤去（任意） ====
uninstall-hermes: ## Hermes コンテナ内の Claude Code を撤去
	sudo bash scripts/08-uninstall-hermes-claude.sh

# ==== 一括 ====
install: check user cloudcli systemd nginx cert auth memory ## Phase 1〜3 を一括実行

verify: ## 動作確認（HTTP/HTTPS 応答コードなど）
	@source .env && \
	echo "→ local CloudCLI:    " && curl -sS -o /dev/null -w '  http://127.0.0.1:%{url_effective}  %{http_code}\n' http://127.0.0.1:$$FORGE_PORT/ && \
	echo "→ public HTTPS:      " && curl -ksS -o /dev/null -w '  https://%{url_effective}  %{http_code}\n' https://$$FORGE_DOMAIN/ && \
	echo "→ memory container:  " && (docker ps --filter name=kks-forge-memory --format '  {{.Names}}  {{.Status}}' || true)

status: ## systemd ステータス
	systemctl --no-pager --full status kks-forge.service || true

logs: ## ログを追いかける
	journalctl -u kks-forge.service -f
