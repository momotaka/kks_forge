# KKS-Forge デプロイ手順（Phase 1〜5）

要件定義書 v3.0 §9 の各 Phase に対応します。
本リポジトリを VPS に `git clone` してから順に走らせます。

```bash
# 例: /opt/kks-forge にクローン（root で）
sudo git clone https://github.com/momotaka/kks_forge.git /opt/kks-forge
cd /opt/kks-forge
sudo cp .env.example .env
sudo $EDITOR .env          # FORGE_DOMAIN, FORGE_LE_EMAIL などを編集
```

> 全ての `make ...` ターゲットは内部で `sudo bash scripts/...` を呼びます。
> `make help` で一覧、`make verify` で動作確認、`make logs` で journalctl 追従。

---

## Phase 1: 最小動作版

ゴール: 「ブラウザで CloudCLI が開く、プロジェクト一覧が見える」

```bash
make check       # Node.js v22+ / docker / nginx / envsubst などの存在チェック
make user        # forge ユーザーと ~/.claude を作成
make cloudcli    # @cloudcli-ai/cloudcli を初回 npx 取得
```

ここまでで Claude Code 自体は未認証。次のコマンドを **手動** で実行して OAuth を済ませる：

```bash
sudo -iu forge
# forge シェルの中で
claude setup-token   # 表示された URL をブラウザで開いて承認
```

SSH ポートフォワード経由で UI を覗くなら：

```bash
# ローカル PC から
ssh -L 3300:127.0.0.1:3300 your-vps
# その後ブラウザで http://localhost:3300/
```

systemd 化は Phase 2 で行うので、この段階の起動確認は `npx` を直接叩いてよい。

---

## Phase 2: 永続化と公開

ゴール: 「PC/スマホのブラウザで `https://forge.kkshd.jp` を開いて使える」

```bash
make systemd     # /etc/systemd/system/kks-forge.service を配置・有効化
make nginx       # /etc/nginx/sites-available/$FORGE_DOMAIN.conf を配置
make cert        # Let's Encrypt 証明書を webroot で取得
make auth        # Basic 認証ユーザーのパスワードを対話入力
```

DNS は事前に `forge.kkshd.jp` → VPS の A レコードを切っておくこと。
許可 IP を絞る場合は `.env` の `FORGE_ALLOW_IPS` に
`203.0.113.10, 198.51.100.0/24` のような形でカンマ区切りで入れて
`make nginx` を再実行する。

確認:

```bash
make verify
```

---

## Phase 3: 記憶統合

ゴール: 「Claude Code が過去の作業内容を覚えている」

```bash
make memory      # /opt/kks-forge/memory/docker-compose.yml を生成して compose up
```

その後、ブラウザで CloudCLI にログインし、MCP 管理 UI で
`http://127.0.0.1:<port>`（mcp-memory-service の既定ポート）を追加。
データは `/var/lib/kks-forge/memory/` に永続化される。

軽い動作確認: 適当なチャットで「Remember: 私の名前は大桃です」→ 新規セッションで
「私の名前を覚えていますか？」と聞く。

---

## Phase 4: プロジェクト整備

ゴール: 「プロジェクト固有の事情を Claude Code が理解した状態で作業できる」

各プロジェクトのルートに `templates/CLAUDE.md.template` をコピーして埋める：

```bash
# 例: /var/www/kks-env を整備する
sudo -iu forge
cp /opt/kks-forge/templates/CLAUDE.md.template /var/www/kks-env/CLAUDE.md
$EDITOR /var/www/kks-env/CLAUDE.md
```

書き込み許可ディレクトリは `$FORGE_HOME/.claude/settings.json` で明示する。例:

```json
{
  "permissions": {
    "allow": [
      "Write(/var/www/kks-env/**)",
      "Bash(git *)",
      "Bash(npm *)"
    ],
    "deny": [
      "Write(/etc/**)",
      "Write(/var/lib/**)"
    ]
  }
}
```

---

## Phase 5: 拡張（任意）

### スケジュール実行（cloudcli-cron 相当）

`plugins/cron/README.md` に systemd timer ベースの最小例を置いてある。
公式 `cloudcli-cron` プラグインが安定したら CloudCLI UI から導入し、
systemd timer は無効化する。

### Telegram 通知ブリッジ

```bash
sudo install -m 0755 /opt/kks-forge/plugins/telegram-notify/notify.sh \
  /opt/kks-forge/plugins/telegram-notify/notify.sh
# ~/.claude/settings.json の hooks に
# plugins/telegram-notify/hooks.json.example の内容をマージ
```

`.env` に `FORGE_TELEGRAM_BOT_TOKEN` と `FORGE_TELEGRAM_CHAT_ID` を入れれば送信される。

### Hermes コンテナ内 Claude Code 撤去

```bash
make uninstall-hermes
```

要件定義書 §8.4 の方針に沿って、Hermes に開発タスクを物理的に振れなくする。
コンテナ自体は維持する（Hermes 本体は秘書として残す）。

---

## トラブルシュート

| 症状 | 切り分け |
|---|---|
| `make systemd` 後に 502 | `journalctl -u kks-forge -f` で起動失敗の原因を見る |
| UI が真っ白 | WebSocket が抜けてない可能性。Nginx の `proxy_set_header Upgrade` 周辺確認 |
| `make cert` が失敗 | DNS が伝播してない／80 番が他で塞がっている |
| Memory MCP が見えない | `docker logs kks-forge-memory`、ポートが要件と一致しているか |

詳細は `docs/operations.md` を参照。
