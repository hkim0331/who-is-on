#!/usr/bin/env racket
#lang racket

(require db)
(define sql3 (sqlite3-connect #:database "who-is-on.sqlite3"))

(define dict
        '(("fukuda"  "福田")
          ("hkimura"  "木村")
          ("kawano"  "河野")
          ("koyanagi"  "小柳")
          ("miyakawa"  "宮川")
          ("murakami"  "村上")
          ("tanaka"  "田中")
          ("tsuda"  "津田")
          ("imac04" "imac04")
          ("imac05" "imac05")
          ("imac06" "imac06")
          ("imac07" "imac07")))

(map
  (lambda (p)
    (query-exec
      sql3
      "update users set jname=$1 where name=$2" (second p) (first p)))
  dict)


