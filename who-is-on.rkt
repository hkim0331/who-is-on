#!/usr/bin/env racket
;;; hkimura, 2019-03-05.
;;; update 2019-03-12, 2019-03-13,
;;;
#lang racket

(require db)

(define (exec cmdline)
    (let* ((proc (apply process* (string-split cmdline)))
           (port (first proc))
           (ret '()))
      (let loop ((line (read-line port)))
        (unless (eof-object? line)
          (set! ret (cons line ret))
          (loop (read-line port))))
      ret))

(define (arp)
  (exec "/usr/sbin/arp -an"))

(define (broadcast)
  )

(define (who-is-on)
  (let ((sql3 (sqlite3-connect #:database "who-is-on.sqlite3")))
    (for ([mac (map (lambda (s) (fourth (string-split s))) (arp))])
      (query-exec sql3 "insert into mac_addrs (mac) values ($1)" mac))
    (disconnect sql3)))

(who-is-on)
