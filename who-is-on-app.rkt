#!/usr/bin/env racket
;;; WiFi で出場状況チェック by hkimura
;;; make install will rewrite this file. end points.
;;;
;;; update 2019-03-13,
;;;        2019-03-14,
;;;        2019-03-17,
;;;        2019-03-23,
;;;        2019-03-25 asynchronous update
;;;        2019-03-28 cancel 2019-03-25, define 'on'
#lang racket

(define VERSION "0.8")

(require db (planet dmac/spin))

(define sql3 (sqlite3-connect #:database (getenv "WIO_DB")))

;; /list で表示すべきユーザの名前
(define *users* '("hkimura" "miyakawa" "kawano" "tanaka"))

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

(define (now)
  (string-split (query-value sql3 "select datetime('now','localtime')")))

;; use macro?
(define (html contents . other)
  (format "~a~a~a"
    header
    (string-join (cons contents other))
    footer))

(define (status? name)
  (define (hh s)
    (string->number (first (string-split s ":"))))
  (let* ((query "select date,time from mac_addrs where mac=$1 order by id desc limit 1")
         (ret (query-rows sql3 query (wifi name))))
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
  (let ((q (string-join-with "or" (map (lambda (s) (format "name='~a'" s)) *users*))))
    (query-list sql3 (format "select wifi from users where ~a" q))))

(define (dates-all)
  (query-list sql3 "select distinct(date) from mac_addrs order by date desc"))

(define status (query-rows sql3 "select date,mac from mac_addrs group by mac"))
(define (exists? date user rows)
  (not (empty?
        (filter (lambda (st)
                  (and (string=? date (vector-ref st 0))
                       (string=? user (vector-ref st 1))))
                rows))))

;;; end points
;; http -f http://localhost:8000/on name=hkimura pass=*****
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
         (displayln "<p><a href='/users/new'>add user ...</a></p>"))))))

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
                (display (format "<p><b>~a</b> " (first-date ret)))
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
             (dates (dates-all))
             (status (query-rows sql3 "select date,mac from mac_addrs group by mac")))
         (with-output-to-string
           (lambda ()
             (display "<table>")
             (for ([d dates])
               (display (format "<tr><td>~a</td>" d))
               (for ([u users])
                 (display (format "<td>~a</td>"
                                  (if (exists? d u status)
                                      "yes"
                                      ""))))
               (display "</tr>"))
             (display "</table>")
             ))
         )))

(displayln "start at 8000/tcp")
;; for listen-ip, read tcp-listen in racket manual.
;;debug
(run #:listen-ip "127.0.0.1" #:port 8000)


