# KKS-Forge

株式会社小出環境サービス向け、Claude Code 開発エージェント環境。
CloudCLI（旧 Claude Code UI）を VPS 上で動かし、Nginx 経由で
`https://forge.kkshd.jp/` から PC / スマホで使えるようにする。

設計の根拠は [`docs/requirements-v3.md`](docs/requirements-v3.md)、
構築手順は [`docs/deployment.md`](docs/deployment.md)、
運用は [`docs/operations.md`](docs/operations.md) を参照。

## クイックスタート

VPS 上で root として：

```bash
git clone https://github.com/momotaka/kks_forge.git /opt/kks-forge
cd /opt/kks-forge
cp .env.example .env
$EDITOR .env                  # FORGE_DOMAIN / FORGE_LE_EMAIL などを設定

make help                     # ターゲット一覧
make install                  # Phase 1〜3 を一括実行
sudo -iu forge claude setup-token   # Claude Code OAuth
make verify
```

`make install` の中身（順番に実行されます）:

1. `make check`    — Node.js v22+ / docker / nginx / envsubst の前提確認
2. `make user`     — `forge` ユーザー作成、`~/.claude` 配置
3. `make cloudcli` — `@cloudcli-ai/cloudcli` を初回 npx 取得
4. `make systemd`  — systemd unit を配置・自動起動
5. `make nginx`    — Nginx 設定（SSL/Basic 認証/許可 IP）
6. `make cert`     — Let's Encrypt 証明書取得
7. `make auth`     — Basic 認証パスワード対話入力
8. `make memory`   — mcp-memory-service を Docker で起動

任意：

- `make uninstall-hermes` — Hermes コンテナ内の Claude Code を撤去（要件定義書 §8.4）

## ディレクトリ構成

```
kks_forge/
├── .env.example                       設定値のサンプル
├── Makefile                           入口（make help でターゲット一覧）
├── docs/
│   ├── requirements-v3.md             要件定義書 v3.0（一次資料）
│   ├── deployment.md                  Phase 1〜5 詳細手順
│   └── operations.md                  起動・停止・バックアップ・残課題
├── scripts/
│   ├── 00-prereq-check.sh             前提コマンド/Node 22+/ポート確認
│   ├── 01-create-user.sh              forge ユーザー作成
│   ├── 02-install-cloudcli.sh         CloudCLI 初回 npx 取得
│   ├── 03-install-systemd.sh          systemd unit 配置
│   ├── 04-install-nginx.sh            Nginx 設定 + IP 制限スニペット
│   ├── 05-issue-cert.sh               Let's Encrypt 取得 (webroot)
│   ├── 06-setup-basic-auth.sh         htpasswd
│   ├── 07-start-memory.sh             docker compose up
│   ├── 08-uninstall-hermes-claude.sh  Hermes 内 Claude Code 撤去
│   └── lib/common.sh                  共通関数 (.env 読み込み等)
├── systemd/
│   └── kks-forge.service.tmpl
├── nginx/
│   └── forge.conf.tmpl
├── memory/
│   └── docker-compose.yml.tmpl
├── plugins/
│   ├── cron/README.md                 systemd timer による cron 雛形
│   └── telegram-notify/
│       ├── notify.sh                  Claude Code hooks から呼ぶ通知
│       └── hooks.json.example         settings.json への追加例
└── templates/
    └── CLAUDE.md.template             各プロジェクト用の CLAUDE.md 雛形
```

## 設計上の決定事項（短く）

- **CloudCLI は npx で都度取得**（要件定義書 §5.1）。アップデート追随を簡単に保つため。
- **`.env` で全変数を吸収**。`scripts/lib/common.sh` の `render_template` が
  `envsubst` で `.tmpl` を `/etc/...` に展開する。
- **mcp-memory-service は `network_mode: host` で 1 コンテナ**。CloudCLI 側 MCP 登録は
  `http://127.0.0.1:<port>` で行う。
- **Nginx は既存のものに sites-available/ で同居**。`make nginx` は他サイトに触らない。
- **Hermes は秘書として残し、Claude Code 同梱だけ撤去**（要件定義書 §7.1 / §8.4）。

## ライセンス・関連

- CloudCLI: AGPL-3.0 / https://github.com/siteboon/claudecodeui
- mcp-memory-service: https://github.com/doobidoo/mcp-memory-service
- Claude Code: https://code.claude.com/docs
