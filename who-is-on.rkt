#!/usr/bin/env racket
;;;
;;; for miyakawa's new seven-hours
;;; hkimura, 2019-03-05.
;;; update 2019-03-12,
;;;
;#lang racket

(require db)

;; by full path
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

; ;; #t if ping returns.
; ;; no use?
; (define (ping? ip . opt)
;   (exec (format "/sbin/ping ~a ~a"
;                 (if (null? opt)
;                     "-t 1"
;                     (first opt))
;                 ip)))

; ;; find string s from list of strings lst.
; ;; no use?
; (define (find-str lst s)
;   (define (F lst r)
;     (cond
;       ((null? lst) #f)
;       ((regexp-match r (first lst)) #t)
;       (else (F (rest lst) r))))
;   (F lst (regexp s)))

(define (who-is-on)
  (let ((sql3 (sqlite3-connect #:database "who-is-on.sqlite3")))
    (for ([mac (map (lambda (s) (fourth (string-split s))) (arp))])
      (query-exec sql3 "insert into mac_addrs (mac) values ($1)" mac))
    (disconnect sql3)))

(define th
  (thread
    (thunk
      (let loop ()
        (who-is-on)
        (sleep 60);; 3600
        (loop)))))

;; (fetch "hkimura" "2019-01-01")
(define (fetch who date)
  (let* ((sql3
          (sqlite3-connect #:database "who-is-on.sqlite3"))
         (wifi
          (query-value
           sql3
           "select wifi from users where name=$1" who))
         (times
          (query-rows
           sql3
           "select time from mac_addrs where mac=$1 and date=$2"
           wifi date)))
    (disconnect sql3)
    times))

(define (names)
  (let ((sql3 (sqlite3-connect #:database "who-is-on.sqlite3")))
    (with-output-to-string
      (lambda ()
        (for ([u (query-rows sql3 "select name from users")])
          (display (format "<li>~a</li>" (vector-ref u 0))))))))
