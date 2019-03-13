#!/usr/bin/env racket
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
(define (html contents)
  (format "~a~a~a" header contents footer))

(define sql3 (sqlite3-connect #:database "who-is-on.sqlite3"))

(get "/users"
     (lambda (req)
       (html
        (with-output-to-string
          (lambda ()
            (for ([u (query-rows sql3 "select name from users")])
              (display (format "<li>~a</li>" (vector-ref u 0)))))))))


(get "/user/:name"
     (lambda (req)
       (let* ((wifi (query-value sql3 "select wifi from users where name=$1"
                                (params req 'name)))
              (today (query-value sql3 "select date('now','localtime')"))
              (ontime (query-list
                       sql3
                       "select ts from ons
                       where wifi=$1 and ts between $2 and $3"
                       wifi
                       (string-append today " 00:00:00")
                       (string-append today " 23:59:59"))))
         (html
          (with-output-to-string
            (lambda ()
              (display (format "<h3>~a, ~a</h3>" (params req 'name) today))
              (display ontime)))))))

(run #:listen-ip #f #:port 8000)
