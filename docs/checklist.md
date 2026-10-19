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
- [ ] alp.yml の matching_groups をアプリのパスに合わせる
- [ ] `make bench-prep` → ベンチ → `make alp` / `make slow` (または `make sql-stats`) / `make pprof`

## 以降のループ
1. `make alp` / `make slow` / `make pprof` で遅い所を特定
2. 手元で直して commit & push
3. デプロイする
   - 1台: サーバーで `make deploy-app` (アプリのみ。mysql を落とさない)
   - 複数台: 手元で `make deploy-app-all`
   - `conf/` の設定を変えた時だけ `make deploy` / `make deploy-all`
4. `make bench-prep` → ベンチ → スコアを記録

## よく効く改善
- インデックス追加 (`make slow` の上位から)
- N+1 解消 (JOIN / IN 句 / キャッシュ)
- 静的ファイルを nginx から直接配信
- `InterpolateParams=true`、コネクションプールの調整 (足りなければ `SetMaxOpenConns(512)` 程度まで)
- Web フレームワークのリクエストログ (chi / echo の logger middleware) を外す
- 変わらないデータはメモリにキャッシュ (`sync.Map` / mutex + map)
- DB を別サーバーへ分離 (使わないサーバーの mysql やアプリは `systemctl disable --now`)

## 複数台に分ける時
- [ ] Makefile の `APP_HOSTS` / `ALL_HOSTS` / `REPO_DIR` を埋める (ssh config の名前と揃える)
- [ ] 全サーバーで deploy key を作り、リポジトリを clone
- [ ] 役割が違うホストは `conf/<hostname>/vars.mk` で `RESTART` を絞る
      - DB 専用: `RESTART := mysql`
      - アプリ専用: `RESTART := $(SERVICE)`
- [ ] 各サーバーで `make collect` → 1台ずつ commit (同時にやると衝突する)
- [ ] アプリの接続先 DB ホストを書き換える (localhost のままになりがち)
- [ ] ログの在り処に注意
      - `make alp` は nginx のいるホスト
      - `make slow` は mysql のいるホスト
      - `make bench-prep` も両方で叩く

## 終了前
- [ ] slow log、アクセスログ、pprof を外す
- [ ] 全サーバーを再起動しても動くか確認 (`systemctl enable`)
- [ ] 最終ベンチ

## 未対応 (必要になったら追加)
- ssh config: 当日 IP が決まってから書く
- pprotein / netdata: alp + pt-query-digest + pprof で足りない時に
