// 当日 main.go に貼るコード片。ビルド対象ではない。
//go:build ignore

package main

import (
	"net/http"
	_ "net/http/pprof"
	"time"

	"github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
)

func pprofServer() {
	// main() の先頭で呼ぶ。終盤に外す
	go http.ListenAndServe("localhost:6060", nil)
}

func dbTuning(cfg *mysql.Config, db *sqlx.DB) {
	cfg.InterpolateParams = true // prepared statement の往復を減らす
	db.SetMaxOpenConns(50)
	db.SetMaxIdleConns(50)
	db.SetConnMaxLifetime(time.Minute)
}
