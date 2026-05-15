# cloudcli-cron 雛形

CloudCLI 標準にスケジュール実行はないので、当面は **systemd timer**
で軽く運用するのが現実的（追加依存ゼロ）。

## 例: 毎朝 8 時に Nginx エラーログを Claude Code に要約させる

`/etc/systemd/system/kks-forge-nginx-digest.service`

```ini
[Unit]
Description=Daily Nginx error log digest via Claude Code

[Service]
Type=oneshot
User=forge
WorkingDirectory=/home/forge
ExecStart=/bin/bash -lc 'tail -n 2000 /var/log/nginx/error.log | claude -p "このNginxエラーログのうち本当に直すべきものを箇条書きで3つに絞ってください。"'
```

`/etc/systemd/system/kks-forge-nginx-digest.timer`

```ini
[Unit]
Description=Daily Nginx error log digest

[Timer]
OnCalendar=*-*-* 08:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl daemon-reload
systemctl enable --now kks-forge-nginx-digest.timer
```

## 公式 cloudcli-cron プラグインに移行したくなったら

CloudCLI のプラグイン一覧で `cloudcli-cron` が安定したら、UI から導入できる。
その時点で上記 systemd timer は無効化する（`systemctl disable --now ...`）。

> 注: `claude -p` 利用は 2026/6/15 以降 Agent SDK クレジット消費に変わる懸念がある
> （要件定義書 §8.2）。発生したら timer を停止して様子を見る。
