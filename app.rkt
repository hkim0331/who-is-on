#!/usr/bin/env racket
;;; WiFi で出場状況チェック
;;; by hkimura,
;;; update 2019-03-13,
#lang racket

(require db (planet dmac/spin))

(define header
  "<!doctype html>
<html>
<head>
<meta name='viewport' content='width=device-width, initial-scale=1.0'/>
<link
 rel='stylesheet'
 href='https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css' integrity='sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T' crossorigin='anonymous'/>
</head>
<body>
<div class='container'>
<h2>Who is on?</h2>")

(define footer
  "<hr>
hiroshi . kimura . 0331 @ gmail . com
</div>
</body>
</html>")

;; macro?
(define (html contents . other)
  (format "~a~a~a"
    header
    (string-join (cons contents other))
    footer))

(define sql3 (sqlite3-connect #:database "who-is-on.sqlite3"))

(get "/users"
  (lambda (req)
    (html
      (string-join
        (map (lambda (s) (format "<li>~a</li>" s))
          (query-list sql3 "select name from users"))))))

(define (wifi name)
  (query-value sql3 "select wifi from users where name=$1" name))

(define (hh:mm s)
  (let ((ret (string-split s ":")))
    (format "~a:~a" (first ret) (second ret))))

(get "/user/:name/:date"
  (lambda (req)
    (let* ((name (params req 'name))
           (date (params req 'date))
           (ret (query-list sql3 "select time from mac_addrs inner join users on mac_addrs.mac=users.wifi where users.name=$1 and date=$2"
      name date)))
      (html
        (format "<h3>~a, ~a</h3>" name date)
        "<p>"
        (string-join (map hh:mm ret) " -> ")
        "</p>"))))

(get "/user/:name"
  (lambda (req)
    (define date first)
    (define (first-date x) (date (first x)))
    (let ((name (params req 'name)))
      (html
        (format "<h3>~a</h3>" name)
        (with-output-to-string
          (lambda ()
            (let loop ((ret (map vector->list (query-rows sql3 "select date,time from  mac_addrs inner join users on mac_addrs.mac=users.wifi where users.name=$1 order by date desc, time" name))))
              (unless (null? ret)
                (display (format "<p><b>~a</b> " (first-date ret)))
                (display
                  (string-join
                    (map (lambda (x) (hh:mm (second x)))
                      (filter (lambda (s) (string=? (date s) (first-date ret))) ret))
                     " -> "))
                (display "</p>")
                (loop (filter (lambda (s) (string<? (date s) (first-date ret))) ret))))))))))

(displayln "start at 8000/tcp")

(run #:listen-ip #f #:port 8000)
