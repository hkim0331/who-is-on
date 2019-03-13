#!/usr/bin/env racket
#lang racket

(require db)

(define sql3 (sqlite3-connect #:database "who-is-on.sqlite3"))

(define data
  '(("hkimura" "c0:a5:3e:50:4:ee")
    ("miyuki" "cc:82:eb:b4:13:58")))

(for ([d data])
  (query-exec sql3 "insert into users (name, wifi) values ($1, $2)"
              (first d) (second d)))

(disconnect sql3)
