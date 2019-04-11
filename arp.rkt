#lang racket

(provide exec exec* arp pad)

(define *arp* (or (getenv "WIO_ARP") "/usr/sbin/arp"))

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

(define (pad mac)
  (define (pad0 s)
    (if (= 1 (string-length s))
        (format "0~a" s)
        s))
  (string-join (map pad0 (string-split mac ":")) ":"))
