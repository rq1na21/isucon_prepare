HOST := $(shell hostname)
CONF := conf/$(HOST)

# ホスト固有の上書き。役割が違う時だけ置く (無くても動く)
#   例) conf/isu3/vars.mk に  RESTART := mysql
-include $(CONF)/vars.mk

# 当日ここだけ書き換える
SERVICE   ?= isucon.go.service
APP_DIR   ?= /home/isucon/webapp/go
BIN       ?= isucon
NGINX_LOG ?= /var/log/nginx/access.log
SLOW_LOG  ?= /var/log/mysql/mysql-slow.log
# deploy で再起動するサービス。DB 専用ホスト等は vars.mk で絞る
RESTART   ?= nginx mysql $(SERVICE)

# 複数台構成。当日 ssh config を書いたら埋める
APP_HOSTS ?= isu1 isu2
ALL_HOSTS ?= isu1 isu2 isu3
# サーバー上でこのリポジトリを置いた場所
REPO_DIR  ?= /home/isucon/webapp
# bench-prep で退避したログの置き場所 (ベンチごとに別ディレクトリ)
LOG_DIR := $(HOME)/logs/$(shell date +%m%d-%H%M%S)

.PHONY: setup collect deploy-app deploy deploy-app-all deploy-all bench-prep alp slow sql-stats pprof

setup:
	bash setup/install.sh

# 初回: サーバーの設定と環境情報をリポジトリに取り込む (ホストごとに分ける)
collect:
	mkdir -p $(CONF)/nginx $(CONF)/mysql $(CONF)/systemd
	sudo cp -r /etc/nginx/. $(CONF)/nginx/
	sudo cp -r /etc/mysql/. $(CONF)/mysql/
	cp /etc/systemd/system/$(SERVICE) $(CONF)/systemd/ || true
	{ nproc; free -h; df -h; cat /etc/os-release; } > $(CONF)/info.txt
	systemctl list-units --type=service --state=running > $(CONF)/services.txt
	sudo chown -R $(USER):$(USER) $(CONF)

# 普段はこっち。アプリだけ入れ替える (mysql を落とさないので buffer pool が温いまま)
deploy-app:
	git pull
	@git log --oneline -1
	cd $(APP_DIR) && go build -o $(BIN)
	sudo systemctl restart $(SERVICE)

# conf/ (nginx / mysql の設定) を変えた時だけ
# RESTART のうち disable したものは起こさない。落ちていても enable なら起こす
deploy:
	git pull
	cd $(APP_DIR) && go build -o $(BIN)
	sudo cp -r $(CONF)/nginx/. /etc/nginx/
	sudo cp -r $(CONF)/mysql/. /etc/mysql/
	[ -f $(CONF)/systemd/$(SERVICE) ] && sudo cp $(CONF)/systemd/$(SERVICE) /etc/systemd/system/ || true
	sudo systemctl daemon-reload
	sudo nginx -t
	for s in $(RESTART); do ! systemctl is-enabled -q $$s || sudo systemctl restart $$s; done

# --- ここから下は手元 (踏み台ではなくローカル) で実行する ---

# 全アプリサーバーにアプリだけ配る。push を忘れると古いまま入るので注意
deploy-app-all:
	@for h in $(APP_HOSTS); do \
	  echo "=== $$h ==="; \
	  ssh $$h 'cd $(REPO_DIR) && make deploy-app' || exit 1; \
	done

# conf/ を変えた時。全台に設定ごと配る
deploy-all:
	@for h in $(ALL_HOSTS); do \
	  echo "=== $$h ==="; \
	  ssh $$h 'cd $(REPO_DIR) && make deploy' || exit 1; \
	done

# --- ここから下はまたサーバーで実行する ---

# ベンチ直前に実行。前回のログは $(HOME)/logs/<日時>/ に退避して比較できるようにする (直近 5 回分だけ残す)
bench-prep:
	mkdir -p $(LOG_DIR)
	-sudo mv $(NGINX_LOG) $(SLOW_LOG) $(LOG_DIR)/
	sudo chown -R $(USER):$(USER) $(LOG_DIR)
	ls -dt $(HOME)/logs/*/ | tail -n +6 | xargs -r rm -rf
	! systemctl is-active -q nginx || sudo nginx -s reopen
	! systemctl is-active -q mysql || sudo mysql -e 'FLUSH SLOW LOGS; TRUNCATE performance_schema.events_statements_summary_by_digest'

# 過去のログを見る: make alp NGINX_LOG=~/logs/<日時>/access.log
alp:
	sudo alp json --config alp.yml --file $(NGINX_LOG)

slow:
	sudo pt-query-digest $(SLOW_LOG) | head -n 300

# slow log なしでもクエリ集計できる (performance_schema)。DB があるサーバーで実行
sql-stats:
	sudo mysql -E -e "SELECT DIGEST_TEXT, COUNT_STAR, ROUND(SUM_TIMER_WAIT/1e12,3) AS sum_sec, ROUND(AVG_TIMER_WAIT/1e12,4) AS avg_sec, SUM_ROWS_EXAMINED, SUM_ROWS_SENT, SUM_NO_INDEX_USED FROM performance_schema.events_statements_summary_by_digest WHERE SCHEMA_NAME NOT IN ('performance_schema','mysql') ORDER BY SUM_TIMER_WAIT DESC LIMIT 20"

# ベンチ中に実行。手元から ssh -L 1080:localhost:1080 isu1 で開く
pprof:
	go tool pprof -http=0.0.0.0:1080 http://localhost:6060/debug/pprof/profile?seconds=60
