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
(define (html contents . other)
  (format "~a~a~a" 
    header 
    (string-join (cons contents other))
    footer))

(define sql3 (sqlite3-connect #:database "who-is-on.sqlite3"))

(get "/users"
     (lambda (req)
       (html
        (with-output-to-string
          (lambda ()
            (for ([u (query-rows sql3 "select name from users")])
              (display (format "<li>~a</li>" (vector-ref u 0)))))))))

(define (hh:mm s)
  (let ((ret (string-split s ":")))
    (format "~a:~a" (first ret) (second ret))))

(define (pp date ontimes)
  (with-output-to-string
    (lambda ()
      (display (format "<p><b>~a</b> " date))
      (display (string-join 
                (map (lambda (dt) (hh:mm (second (string-split dt))))
                  ontimes)
                " -> "))
      (display "</p>"))))

;; can not find 'redirect'. so ...
(define (name-date name date)
  (let* ((wifi (query-value 
                  sql3 "select wifi from users where name=$1" name))
         (ontimes (query-list
                    sql3
                    "select timestamp from mac_addrs where mac=$1 and timestamp between $2 and $3"
                    wifi
                    (string-append date " 00:00:00")
                    (string-append date " 23:59:59"))))
    (pp date ontimes)))

(get "/user/:name/:date"
  (lambda (req)
    (let ((name (params req 'name))
          (date (params req 'date)))
      (html
        (format "<h3>~a</h3>" name)
        (name-date name date)))))

;; 「今日の」じゃなく、「彼の」にするか。
(get "/user/:name"
  (lambda (req)
    (let ((name (params req 'name))
          (date (query-value sql3 "select date('now','localtime')")))
      (html
        (format "<h3>Today's ~a</h3>" name)
        (name-date name date)))))

(displayln "start at 8000/tcp")

(run #:listen-ip #f #:port 8000)



