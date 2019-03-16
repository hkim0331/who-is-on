#!/usr/bin/env racket
;;; WiFi で出場状況チェック
;;; by hkimura,
;;; update 2019-03-13,
;;;        2019-03-14,
#lang racket
(require db (planet dmac/spin))

(define VERSION "0.5.4")

(define sql3 (sqlite3-connect #:database "who-is-on.sqlite3"))

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
<h2>Who is on?</h2>
<p><a href='/w/w/w/w/w/w/w/users'>back</a></p>
")

(define footer
  (format "<hr>
hiroshi . kimura . 0331 @ gmail . com, ~a.
</div>
</body>
</html>
" VERSION))

;; use macro?
(define (html contents . other)
  (format "~a~a~a"
    header
    (string-join (cons contents other))
    footer))

(post "/users/create"
  (lambda (req)
    (query-exec
      sql3
      "insert into users (name, wifi) values ($1, $2)"
      (params req 'name)
      (params req 'wifi))
    (html "<p>OK./p>")))

(get "/users/new"
  (lambda (req)
    (html
     (with-output-to-string
       (lambda ()
          (displayln "<form method='post' action='/users/create'>")
          (displayln "<table>")
          (displayln "<tr><th>name</th><td><input name='name'></td></tr>")
          (displayln "<tr><th>wifi</th><td><input name='wifi'></td></tr>")
          (displayln "</table>")
          (displayln "<p><input type='submit' class='btn btn-primary' value='add'></p>")
          (displayln "</form>"))))))

(get "/users"
  (lambda (req)
    (html
     (with-output-to-string
       (lambda ()
         (displayln "<ul>")
         (for ([u (query-list sql3 "select name from users")])
           (displayln (format "<li><a href='/w/w/w/w/w/w/w/user/~a'>~a</a>" u u)))
         (displayln "</ul>")
         (displayln "<p><a href='/w/w/w/w/w/w/w/users/new'>add user ...</a></p>"))))))


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

;; for listen-ip, read tcp-listen in racket manual.
(run #:listen-ip "127.0.0.1" #:port 8000)
