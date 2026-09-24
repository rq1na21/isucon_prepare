# 当日ここだけ書き換える
SERVICE   ?= isucon.go.service
APP_DIR   ?= /home/isucon/webapp/go
BIN       ?= isucon
NGINX_LOG ?= /var/log/nginx/access.log
SLOW_LOG  ?= /var/log/mysql/mysql-slow.log
# alp で集約するパス (例: '/api/user/[0-9]+,/image/.+')
ALP_M     ?= ''

HOST := $(shell hostname)
CONF := conf/$(HOST)

.PHONY: setup collect deploy bench-prep alp slow pprof

setup:
	bash setup/install.sh

# 初回: サーバーの設定をリポジトリに取り込む (ホストごとに分ける)
collect:
	mkdir -p $(CONF)/nginx $(CONF)/mysql $(CONF)/systemd
	sudo cp -r /etc/nginx/. $(CONF)/nginx/
	sudo cp -r /etc/mysql/. $(CONF)/mysql/
	cp /etc/systemd/system/$(SERVICE) $(CONF)/systemd/ || true
	sudo chown -R $(USER):$(USER) $(CONF)

deploy:
	git pull
	cd $(APP_DIR) && go build -o $(BIN)
	sudo cp -r $(CONF)/nginx/. /etc/nginx/
	sudo cp -r $(CONF)/mysql/. /etc/mysql/
	[ -f $(CONF)/systemd/$(SERVICE) ] && sudo cp $(CONF)/systemd/$(SERVICE) /etc/systemd/system/ || true
	sudo systemctl daemon-reload
	sudo nginx -t
	sudo systemctl restart nginx mysql $(SERVICE)

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
