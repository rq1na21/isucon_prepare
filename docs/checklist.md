# 当日チェックリスト

## 最初の1時間
- [ ] マニュアル・アプリ概要を読む (全員)
- [ ] 初回ベンチを回してスコアを記録
- [ ] `~/.ssh/config` に isu1〜3 を登録
- [ ] 各サーバーで deploy key を作成し GitHub に登録 (`ssh-keygen -t ed25519`)
- [ ] webapp を git 管理 → このリポジトリの Makefile / setup / templates をコピー
- [ ] `make setup` → `make collect` → commit
- [ ] Makefile 先頭の変数 (SERVICE, APP_DIR, BIN) を書き換え
- [ ] templates/ の nginx ログ形式・slow log を反映 → `make deploy`
- [ ] snippets の pprof を埋め込む
- [ ] `make bench-prep` → ベンチ → `make alp` / `make slow` / `make pprof`

## よく効く改善
- インデックス追加 (`make slow` の上位から)
- N+1 解消 (JOIN / IN 句 / キャッシュ)
- 静的ファイルを nginx から直接配信
- `InterpolateParams=true`、コネクションプールの調整
- 変わらないデータはメモリにキャッシュ (`sync.Map` / mutex + map)
- DB を別サーバーへ分離

## 終了前
- [ ] slow log、アクセスログ、pprof を外す
- [ ] 全サーバーを再起動しても動くか確認 (`systemctl enable`)
- [ ] 最終ベンチ

## 未対応 (必要になったら追加)
- ssh config: 当日 IP が決まってから書く
- pprotein / netdata: alp + pt-query-digest + pprof で足りない時に
- 複数台への一括 deploy: DB 分離時に `ssh isu2 make deploy` 等を足す
