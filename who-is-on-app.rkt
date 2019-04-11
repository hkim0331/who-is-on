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
;;;        2019-04-09 merge miyakawa's weekday.rkt
;;;        2019-04-10 japase name, display order
;;;        2019-04-11 いるよボタン

(require db web-server/http
         (planet dmac/spin)
         "weekday.rkt" "arp.rkt")

(define VERSION "0.14.1")

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
  (query-list sql3 "select name from users order by cat desc,name"))

(define (only-people)
  (filter (lambda (s) (not (regexp-match #rx"^imac" s))) (users)))

(define (now)
  (string-split (query-value sql3 "select datetime('now','localtime')")))

(define (dd-mm s)
  (substring s 5 10))

(define (weekdays days)
  (filter weekday? days))

;; macro?
(define (html contents . other)
  (format "~a~a~a"
    header
    (string-join (cons contents other))
    footer))

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

(define (wifi? mac)
  (query-maybe-value sql3 "select wifi from users where wifi=$1" mac))

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

;;FIXME, not DRY
(define (users-wifi)
  (let ((q (string-join-with
            "or"
            (map (lambda (s) (format "name='~a'" s)) (only-people)))))
    (query-list
     sql3
     (format "select wifi from users where ~a order by cat desc, name" q))))

(define (dates-all)
  (query-list
   sql3
   "select distinct(date) from mac_addrs order by date desc"))

(define (wifi->name wifi)
  (first (query-list sql3 "select name from users where wifi=$1" wifi)))

(define *name-jname*
  (query-rows sql3 "select name,jname from users"))

(define (insert mac)
  (let* ((now (now)))
    (query-exec
     sql3
     "insert into mac_addrs (mac,date,time) values ($1,$2,$3)"
     mac (first now) (second now))
    "OK"))

;; FIXME: if did not find name in *name-jname*, j must be return name.
(define (j name)
  (call/cc
   (lambda (return)
     (for ([pair *name-jname*])
       (when (string=? name (vector-ref pair 0))
         (return (vector-ref pair 1)))))))

;; not collect, but enough.
(define (in? ip)
  (regexp-match (regexp (getenv "WIO_SUBNET")) ip))

(define (ip->mac ip)
  (call/cc
   (lambda (return)
     (for ([line (arp)])
       (when (string=?
              (first (regexp-match #rx"[0-9]+.[0-9]+.[0-9]+.[0-9]+" line))
              ip)
         (return (fourth (string-split line)))))
     (return #f))))

;;;
;;; end points
;;;

(get "/i-m-here"
  (lambda (req)
    (let ((client-ip (request-client-ip req)))
      (if (in? client-ip)
          (let ((mac (pad (ip->mac client-ip))))
            (if (wifi? mac)
                (begin
                  (insert mac)
                  (html (format "OK.")))
                (html (format "not registered."))))
          (html "not in C104.")))))

(get "/info"
  (lambda (req)
    (html
      (format "<p>WIO_DB: ~a</p>" (getenv "WIO_DB"))
      (format "<p>WIO_SUBNET: ~a</p>" (getenv "WIO_SUBNET")))))

;; http -f http://localhost:8000/on name=***** pass=*****
(post "/on"
      (lambda (req)
        (let ((pass (query-value sql3 "select pass from pass"))
              (wifi (query-maybe-value
                     sql3
                     "select wifi from users where name=$1"
                     (params req 'name))))
          (if (and (string=? pass (params req 'pass)) wifi)
              (insert wifi)
              "NG"))))

(get "/"
  (lambda ()
    (html
      "<p>try <a href='/users'>here</a>.</p>")))

(post "/users/create"
  (lambda (req)
    (query-exec
      sql3
      "insert into users (name, jname, wifi) values ($1, $2, $3)"
      (params req 'name)
      (params req 'jname)
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
          (displayln "<tr><th>日本名</th><td><input name='jname'></td></tr>")
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
         (for ([u (users)])
           (displayln (format "<li class='~a'><a href='/user/~a'>~a</a></li>"
                              (if (status? u) "red" "black")
                              u (j u))))
         (displayln "</ul>")
         (displayln
          "<p><a href='/list' class='btn btn-primary btn-sm'>list</a>
<a href='/i-m-here' class='btn btn-danger btn-sm'>いるよ</a>
<a href='/users/new' class='btn btn-primary btn-sm'>add user</a>
</p>"))))))

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

;;2019-04-10, j
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
                (display (format "<td> ~a, </td>" (j (wifi->name u)))))
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

(get "/info"
  (lambda (req)
    (html
      (format "<p>WIO_DB: ~a</p>" (getenv "WIO_DB"))
      (format "<p>WIO_SUBNET: ~a</p>" (getenv "WIO_SUBNET")))))
;;
;; start server
;;
(displayln "start at 8000/tcp")
(run #:listen-ip "127.0.0.1" #:port 8000)
;; for debug
(run #:listen-ip #f #:port 8000)
