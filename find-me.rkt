#!/usr/bin/env racket
#lang racket
;; origin: who-is-on/find-me.rkt
;; description: kawano, tanaka, fukuda の mac-address が見つけられない原因は？
;;
(require db)

(define *debug* false)

(define db (sqlite3-connect #:database (if *debug*
                                           "./who-is-on.sqlite3"
                                           "/srv/who-is-on/who-is-on.sqlite3")))
(define wifi
  (lambda (name)
    (query-value db "select wifi from users where name=$1" name)))

(define entries
  (lambda (mac date)
    (query-list db
                "select time from mac_addrs where mac=$1 and date=$2"
                mac
                date)))
(define today
  (lambda ()
    (query-value db "select date('now', 'localtime');")))

(define find-me-db
  (lambda ()
    (entries (wifi (if *debug* "hkimura" (getenv "USER"))) (today))))

;; under construction, 2019-04-09
(define find-me-arp
  (lambda ()
    "under construction"))
