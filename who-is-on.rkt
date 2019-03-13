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

(define (exec* cmdline)
  (apply process* (string-split cmdline)))


(define (arp)
  (exec "/usr/sbin/arp -an"))

(define (bc net from to)
  (let ((cmd "/sbin/ping")
        (arg "-t 2"))
    (map thread-wait
         (for/list ([i (range from to)])
           (let ((cmdline (format "~a ~a ~a.~a" cmd arg net i)))
             (thread (thunk (exec* cmdline))))))
    #t))

(define (broadcast)
  (let ((net "10.0.34"))
    (bc net 1 50)
    (bc net 51 100)
    (bc net 101 150)
    (bc net 151 200)
    (bc net 201 254)))

(define (who-is-on)
  (let ((sql3 (sqlite3-connect #:database "who-is-on.sqlite3")))
    (for ([mac (map (lambda (s) (fourth (string-split s))) (arp))])
      (unless (regexp-match #rx"incomplete" mac)
        (query-exec sql3 "insert into mac_addrs (mac) values ($1)" mac)))
    (disconnect sql3)))

(bc "10.0.34" 1 254)
(who-is-on)

