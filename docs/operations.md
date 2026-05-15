# KKS-Forge 運用ガイド

要件定義書 v3.0 §6 非機能要件・§8 残課題 を踏まえた、日常運用のメモ。

## 起動・停止・状態確認

```bash
sudo systemctl status kks-forge      # 状態
sudo systemctl restart kks-forge     # 再起動
sudo systemctl stop kks-forge        # 停止
sudo journalctl -u kks-forge -f      # ログ追従
```

`make` ターゲットでも代用可：

```bash
make status
make logs
make verify    # HTTP/HTTPS/Docker 応答コードまとめ
```

## バージョンアップ

CloudCLI は `npx --yes ${FORGE_CLOUDCLI_PKG}` で都度取得しているので、
systemd を再起動するだけで最新版に追随する：

```bash
sudo systemctl restart kks-forge
```

固定バージョンに留めたい場合は `.env` の `FORGE_CLOUDCLI_PKG` を
`@cloudcli-ai/cloudcli@<version>` の形に書き換える。

## バックアップ対象

| パス | 中身 | 推奨周期 |
|---|---|---|
| `${FORGE_HOME}/.claude/` | Claude Code セッション・設定 | 毎日 |
| `${FORGE_MEMORY_DATA_DIR}` | mcp-memory-service の SQLite/Chroma | 毎日 |
| `/etc/nginx/sites-available/${FORGE_DOMAIN}.conf` | Nginx 設定 | 変更時 |
| `/etc/nginx/.htpasswd-forge` | Basic 認証ハッシュ | 変更時 |
| `/etc/letsencrypt/` | TLS 証明書（certbot が自動更新） | certbot 自身が管理 |

シンプル例（rsync で別ホストに退避）：

```bash
sudo rsync -aHAX --delete \
  ${FORGE_HOME}/.claude/ ${FORGE_MEMORY_DATA_DIR}/ \
  /etc/nginx/sites-available/${FORGE_DOMAIN}.conf \
  /etc/nginx/.htpasswd-forge \
  backup@store:/srv/backup/kks-forge/$(hostname)/
```

## 監視ポイント

- `kks-forge.service` の `Active: active (running)`
- `kks-forge-memory` コンテナの `Status: Up`
- Nginx エラーログ `${FORGE_LOG_DIR}/nginx-error.log`
- Let's Encrypt 更新（`certbot renew --dry-run` は `make cert` でも回せる）

Hermes 側に「KKS-Forge ヘルスチェック」を一本生やすのが理想：

```
curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:${FORGE_PORT}/  → 200/401/403 以外なら通知
docker inspect -f '{{.State.Status}}' kks-forge-memory → 'running' 以外なら通知
```

## 残課題（要件定義書 §8 と対応）

| ID | 課題 | 現在の扱い |
|---|---|---|
| 8.1 | サブスク規約 | 個人利用範囲としてリスク受容（Pro/Max OAuth を CloudCLI から使う） |
| 8.2 | 2026/6/15 以降の Agent SDK クレジット | CloudCLI は TUI 相当で `-p` 非使用と想定。`make verify` 後に念のため `claude -p` 利用箇所を監視 |
| 8.3 | Telegram 連携不在 | `plugins/telegram-notify/` でフック対応済 |
| 8.4 | Hermes 内 Claude Code | `make uninstall-hermes` で撤去 |
| 8.5 | 認証強化 | Phase 1 は Basic 認証 + IP 制限。将来 OAuth/SAML 検討 |

## ロールバック

`make` で行った変更は次の手で巻き戻せる：

```bash
sudo systemctl disable --now kks-forge.service
sudo rm /etc/systemd/system/kks-forge.service
sudo rm /etc/nginx/sites-enabled/${FORGE_DOMAIN}.conf
sudo rm /etc/nginx/sites-available/${FORGE_DOMAIN}.conf
sudo nginx -t && sudo systemctl reload nginx
sudo docker compose -f /opt/kks-forge/memory/docker-compose.yml down
```

ユーザー `forge` とそのホームは消さずに残しておくこと（記憶・履歴が入っている）。
完全消去したい場合のみ `sudo userdel -r forge` を実行する。
