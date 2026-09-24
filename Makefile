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
# alp で集約するパス (例: '/api/user/[0-9]+,/image/.+')
ALP_M     ?= ''
# deploy で再起動するサービス。DB 専用ホスト等は vars.mk で絞る
RESTART   ?= nginx mysql $(SERVICE)

# 複数台構成。当日 ssh config を書いたら埋める
APP_HOSTS ?= isu1 isu2
ALL_HOSTS ?= isu1 isu2 isu3
# サーバー上でこのリポジトリを置いた場所
REPO_DIR  ?= /home/isucon/webapp

.PHONY: setup collect deploy-app deploy deploy-app-all deploy-all bench-prep alp slow pprof

setup:
	bash setup/install.sh

# 初回: サーバーの設定をリポジトリに取り込む (ホストごとに分ける)
collect:
	mkdir -p $(CONF)/nginx $(CONF)/mysql $(CONF)/systemd
	sudo cp -r /etc/nginx/. $(CONF)/nginx/
	sudo cp -r /etc/mysql/. $(CONF)/mysql/
	cp /etc/systemd/system/$(SERVICE) $(CONF)/systemd/ || true
	sudo chown -R $(USER):$(USER) $(CONF)

# 普段はこっち。アプリだけ入れ替える (mysql を落とさないので buffer pool が温いまま)
deploy-app:
	git pull
	@git log --oneline -1
	cd $(APP_DIR) && go build -o $(BIN)
	sudo systemctl restart $(SERVICE)

# conf/ (nginx / mysql の設定) を変えた時だけ
deploy:
	git pull
	cd $(APP_DIR) && go build -o $(BIN)
	sudo cp -r $(CONF)/nginx/. /etc/nginx/
	sudo cp -r $(CONF)/mysql/. /etc/mysql/
	[ -f $(CONF)/systemd/$(SERVICE) ] && sudo cp $(CONF)/systemd/$(SERVICE) /etc/systemd/system/ || true
	sudo systemctl daemon-reload
	sudo nginx -t
	sudo systemctl restart $(RESTART)

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

# ベンチ直前に実行
bench-prep:
	sudo truncate -s 0 $(NGINX_LOG) $(SLOW_LOG)

alp:
	sudo alp json --file $(NGINX_LOG) --sort sum -r -m $(ALP_M) -o count,method,uri,min,avg,max,sum | head -n 40

slow:
	sudo pt-query-digest $(SLOW_LOG) | head -n 300

# ベンチ中に実行。手元から ssh -L 1080:localhost:1080 isu1 で開く
pprof:
	go tool pprof -http=0.0.0.0:1080 http://localhost:6060/debug/pprof/profile?seconds=60
