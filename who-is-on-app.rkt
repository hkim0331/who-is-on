#!/usr/bin/env racket
#lang racket
;;;
;;; WiFi で出場状況チェック by hkimura
;;; make install will rewrite this file suitable for production
;;;
;;; update 2019-03-13,
;;;        2019-03-14,
;;;        2019-03-17,
;;;        2019-03-23,
;;;        2019-03-25 asynchronous update
;;;        2019-03-28 cancel 2019-03-25, define 'on'
;;;        2019-04-03 for*/list
;;;
(require db (planet dmac/spin) "weekday.rkt")

(define VERSION "0.9.5")

;(display (format "WIO_DB: ~a" (or (getenv "WIO_DB") "who-is-on.sqlite3")))

(define sql3 (sqlite3-connect #:database (or (getenv "WIO_DB") "who-is-on.sqlite3")))

(define header
  "<!doctype html>
<html>
<head>
<meta name='viewport' content='width=device-width, initial-scale=1.0'/>
<link
 rel='stylesheet'
 href='https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css' integrity='sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T' crossorigin='anonymous'/>
<style>
.red { color: red; }
.black { color: black; }
</style>
</head>
<body>
<div class='container'>
<h2>Who is on?</h2>
<p><a href='/users'>back</a></p>
")

(define footer
  (format "<hr>
hiroshi . kimura . 0331 @ gmail . com, ~a,
<a href='https://github.com/hkim0331/who-is-on'>github</a>
</div>
</body>
</html>
" VERSION))

(define (users)
  (let ((all (query-list sql3 "select name from users")))
    (filter (lambda (s) (not (regexp-match #rx"^imac" s))) all)))

(define (now)
  (string-split (query-value sql3 "select datetime('now','localtime')")))

(define (dd-mm s)
  (substring s 5 10))

;(define (weekday? s)
;  (let ((d (apply date (map string->number (string-split s "-")))))
;    (not (or (saturday? d) (sunday? d)))))

(define (weekdays days)
  (filter weekday? days))

;; use macro?
(define (html contents . other)
  (format "~a~a~a"
    header
    (string-join (cons contents other))
    footer))

;; replace with Redis?
(define (status? name)
  (define (hh s)
    (string->number (first (string-split s ":"))))
  (let*
      ((ret
        (query-rows
         sql3
         "select date,time from mac_addrs where mac=$1 order by id desc limit 1"
         (wifi name))))
    (if (null? ret)
        false
        (let* ((now (now)))
          (and (string=? (first now) (vector-ref (first ret) 0))
               ;; too loose?
               (<= (- (hh (second now)) (hh (vector-ref (first ret) 1))) 1))))))

(define (wifi name)
  (query-value sql3 "select wifi from users where name=$1" name))

(define (hh:mm s)
  (let ((ret (string-split s ":")))
    (format "~a:~a" (first ret) (second ret))))

(define (interpose sep xs)
  (define (I sep xs ret)
    (if (null? xs)
        ret
        (I sep (cdr xs) (cons sep (cons (car xs) ret)))))
  (if (null? xs)
      '()
      (reverse(cdr (I sep xs '())))))

(define (string-join-with sep strings)
  (string-join (interpose sep strings)))

(define (users-wifi)
  (let ((q (string-join-with "or" (map (lambda (s) (format "name='~a'" s)) (users)))))
    (query-list sql3 (format "select wifi from users where ~a" q))))

(define (dates-all)
  (query-list sql3 "select distinct(date) from mac_addrs order by date desc"))

(define (wifi->name wifi)
  (query-list sql3 "select name from users where wifi=$1" wifi))

;;; end points
;; http -f http://localhost:8000/on name=***** pass=*****
(post "/on"
      (lambda (req)
        (let ((pass (query-value sql3 "select pass from pass"))
              (wifi (query-maybe-value
                     sql3
                     "select wifi from users where name=$1"
                     (params req 'name))))
          (if (and (string=? pass (params req 'pass)) wifi)
              (let* ((now (now)))
                (query-exec
                 sql3
                 "insert into mac_addrs (mac,date,time) values ($1,$2,$3)"
                 wifi (first now) (second now))
                "OK")
              "NG"))))

(get "/"
  (lambda ()
    (html
      "<p>try <a href='/users'>here</a>.</p>")))

(post "/users/create"
  (lambda (req)
    (query-exec
      sql3
      "insert into users (name, wifi) values ($1, $2)"
      (params req 'name)
      (params req 'wifi))
    (html "<p>OK.</p>")))

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
           (displayln (format "<li class='~a'><a href='/user/~a'>~a</a></li>"
                              (if (status? u) "red" "black")
                              u u)))
         (displayln "</ul>")
         (displayln
          "<p>[ <a href='/list'>list</a> | <a href='/users/new'>add user</a> ]</p>"))))))

(get "/user/:name/:date"
  (lambda (req)
    (let* ((name (params req 'name))
           (date (params req 'date))
           (ret (query-list sql3 "select time from mac_addrs inner join users on mac_addrs.mac=users.wifi where users.name=$1 and date=$2"
                 name date)))
      (html
        (format "<h3>~a, ~a</h3>" name date)
        "<p>"
        (string-join (map hh:mm ret) " &rarr; ")
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
                (display (format "<p><b>~a</b> " (dd-mm (first-date ret))))
                (display
                  (string-join
                    (map (lambda (x) (hh:mm (second x)))
                      (filter (lambda (s) (string=? (date s) (first-date ret))) ret))
                    " &rarr; "))
                (display "</p>")
                (loop (filter (lambda (s) (string<? (date s) (first-date ret))) ret))))))))))

;;2019-04-03
(get "/list"
     (lambda (req)
       (let ((users (users-wifi))
             (dates (weekdays (dates-all)))
             (status (query-rows sql3 "select date,mac from mac_addrs group by date")))
         (html
          (with-output-to-string
            (lambda ()
              (display "<table>")
              (display "<tr><th></th>")
              (for ([u users])
                (display (format "<td>~a</td>" (wifi->name u))))
              (display "</tr>")
              (for ([d dates])
                (let ((st
                       (query-list
                        sql3
                        "select distinct(mac) from mac_addrs where date=$1" d)))
                  (display (format "<tr><th>~a</th>" (dd-mm d)))
                  (for ([u users])
                    (display (format "<td style='text-align:center;'>~a</td>"
                                     (if (member u st string=?)
                                         "😀"
                                         "")))))
                (display "</tr>"))
              (display "</table>")))))))

;;
;; start server
;;
(displayln "start at 8000/tcp")
(run #:listen-ip "127.0.0.1" #:port 8000)
