#!/usr/bin/env racket
;;; hkimura, 2019-03-05.
;;; update 2019-03-12,
;;;        2019-03-13,
;;;        2019-03-14,

#lang racket

(require db)

(define *db* (or (getenv "WIO_DB") "./who-is-on.sqlite3"))
(define *arp* (or (getenv "WIO_ARP") "/usr/sbin/arp"))
(define *ping* (or (getenv "WIO_PING") "/bin/ping"))
(define *subnet* (or (getenv "WIO_SUBNET") "10.0.34"))

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
  (exec (format "~a -an" *arp*)))

(define (broadcast)
  (define (bc net from to)
    (map thread-wait
         (for/list ([i (range from to)])
           (let ((cmdline (format "~a -c 2 -t 2 ~a.~a" *ping* net i)))
             (thread (thunk (exec* cmdline))))))
    #t)
  (bc *subnet* 1 254))

(define (who-is-on)
  (let ((sql3 (sqlite3-connect #:database *db*)))
    (for ([mac (map (lambda (s) (fourth (string-split s))) (arp))])
      (unless (regexp-match #rx"incomplete" mac)
        (query-exec sql3 "insert into mac_addrs (mac) values ($1)" mac)))
    (display (query-value sql3 "select datetime('now', 'localtime')"))
    (displayln " update")
    (disconnect sql3)))

(and (broadcast) (who-is-on))
