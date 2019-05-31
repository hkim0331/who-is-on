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
;;;        2019-04-17 レイアウト変更、redmine、l99 へのリンク、絵文字
;;;        2019-05-01 /list and /list-all
;;;        2019-05-20 滞留時間
;;;        2019-05-27 /list にコメント
;;;        2019-05-27 土日をカラー表示
;;;        2019-05-29 ryuto-circuit へのリンク
;;;        2019-05-30 amend, under construction

(require db
         web-server/http
         (planet dmac/spin)
         "weekday.rkt"
         "arp.rkt")

(define VERSION "0.17.5.2")

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
.red   { color: red; }
.black { color: black; }
.blue  { color: blue; }
</style>
</head>
<body>
<div class='container'>
<h2>Who is on?</h2>
<p>
<a href='/users' class='btn btn-outline-primary btn-sm'>back</a>
<a href='https://rm4.melt.kyutech.ac.jp' class='btn btn-outline-primary btn-sm'>redmine</a>
<a href='https://l99.melt.kyutech.ac.jp' class='btn btn-outline-primary btn-sm'>L99</a>
<a href='http://rc.melt.kyutech.ac.jp:3000' class='btn btn-outline-primary btn-sm'>rc</a>
</p>
")

(define footer
  (format "<hr>
hiroshi . kimura . 0331 @ gmail . com, ~a,
<a href='https://github.com/hkim0331/who-is-on'>github</a>
</div>
</body>
</html>
" VERSION))

(define (hh:mm:ss->sec s)
  (let ((ret (map string->number (string-split s ":"))))
    (+ (* (first ret) 3600) (* (second ret) 60) (third ret))))

(define (time-diff t2 t1)
  (- (hh:mm:ss->sec t2)
     (hh:mm:ss->sec t1)))

(define (stays user)
  (map
   vector->list
   (query-rows
    sql3
    "select date,time from mac_addrs
inner join users on users.wifi=mac_addrs.mac
where users.name=$1" user)))

(define (total-stay-second u)
  (define (first-last xs)
    (list (first xs) (first (reverse xs))))
  (define (diff xs)
    (time-diff (second (second xs))
               (second (first xs))))
  (let ((stays (stays u)))
    (apply + (map diff (map first-last (group-by first stays))))))

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
(define (html . body)
  (format "~a~a~a"
    header
    (string-join body)
    footer))

;;want rewrite
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
               ;; max 2 hours
               (<= (- (hh (second now)) (hh (vector-ref (first ret) 1))) 1))))))

;; CHECK: query-maybe-value?
(define (wifi name)
  (query-value sql3 "select wifi from users where name=$1" name))

(define (wifi? mac)
  (query-maybe-value sql3 "select id wifi from users where wifi=$1" mac))

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

(define (dates days)
  (query-list
   sql3
   (format "select distinct(date) from mac_addrs order by date desc limit ~a" days)))

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
  (let ((subnet (getenv "WIO_SUBNET")))
    (and subnet (regexp-match (regexp subnet) ip))))

(define (ip->mac ip)
  (call/cc
   (lambda (return)
     (for ([line (arp)])
       (when (string=?
              (first (regexp-match #rx"[0-9]+.[0-9]+.[0-9]+.[0-9]+" line))
              ip)
         (return (fourth (string-split line)))))
     (return #f))))

;;0.14.2
(define (x-real-ip req)
  (let ((headers
         (filter
          (lambda (x) (bytes=? #"X-Real-IP" (header-field x)))
          (request-headers/raw req))))
    (if (null? headers)
        "not found"
        (bytes->string/latin-1 (header-value (first headers))))))

;;;
;;; end points
;;;

;; 2019-05-30
;; 出席記録しそこなった学生のために
;; need auth
(get "/amend"
  (lambda (req)
(html
  "<h3>amend(under construction)</h3>
   <form method='post' action='/amend'>
    <p>admin <input name='admin'> password <input type='password' name='pass'></p>
    <p>who?<input name='name'></p>
    <p>when<input name='date' placeholder='yyyy-mm-dd'></p>
    <p><input type='submit' value='amend'></p>
</form>")))

(post "/amend"
  (lambda (req)
    (let ((admin (params req 'admin))
          (pass (params req 'pass))
          (wifi (wifi (params req 'name))))
      (if (string=? (params req 'pass)
                    (query-value sql3 "select pass from pass"))
        (begin
          (query-exec
            sql3
            "insert into mac_addrs (mac, date, time) values ($1, $2, $3)"
            wifi (params req 'date) "12:00:00")
          (html "<p>OK. <a href='/'>back</a></p>"))
        (html "<p>bad password. <a href='/amend'>amend</a> or <a href='/'>back</a></p>")))))

(get "/stays/:user"
     (lambda (req)
       (format "~a" (stays (params req 'user)))))

;; 本当は get じゃなくて post だな。
;; href='/i-m-here' で飛ばしたいがために get
(get "/i-m-here"
  (lambda (req)
    (let ((client-ip (x-real-ip req)))
      (if (in? client-ip)
        (let ((mac (pad (ip->mac client-ip))))
             (displayln (format "mac: ~a" mac))
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

;;2019-05-31, 0.18
(define (start-time uname day)
  (query-maybe-value
   sql3
   "select time from mac_addrs where mac=$1 and date=$2 order by time limit 1"
   (wifi uname) day))

(get "/users"
  (lambda (req)
    (html
     (with-output-to-string
       (lambda ()
         (displayln "<p>( ) は 4 月から通算の研究室滞留時間。<br>
こんなんで卒論、PBL できる？</p>")
         (displayln "<div class='container'><table>")
         (for ([u (users)])
           (displayln
            (format "<tr><td>~a</a></td><td><a href='/user/~a'>~a</a> (~a~a)</td><tr>"
                    (if (status? u) "😀" "▪️")
                    u
                    (j u)
                    (quotient (total-stay-second u) 3600)
                    (let ((st (start-time u (first (now)))))
                      (if st
                          (format ", ~a~~" st)
                          "")))))
         (displayln "</table></div><br>")
         (displayln
          "<p>
<a href='/i-m-here' class='btn btn-outline-primary btn-sm'>いるよ 😀</a>
<a href='/list' class='btn btn-outline-primary btn-sm'>list</a>
<a href='/amend' class='btn btn-primary btn-sm'>amend</a>
<a href='/users/new' class='btn btn-primary btn-sm'>add</a>
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

;;FIXME: hash or vector?
(define (color n)
  (cond
    ((= n 0) "red")
    ((= n 6) "blue")
    (else "black")))

;; color weekends
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
                (let ((the-date (first-date ret)))
                (display (format "<p><b class='~a'>~a</b> "
                  (color (day-of-week the-date))
                  (dd-mm the-date)))
                (display
                  (string-join
                    (map (lambda (x) (hh:mm (second x)))
                      (filter (lambda (s) (string=? (date s) the-date)) ret))
                    " &rarr; "))
                (display "</p>")
                (loop (filter (lambda (s) (string<? (date s) the-date)) ret)))))))))))

;; 2019-05-01
;; bug: must not redefine list!
(define (list-days days)
  (let ((users (users-wifi))
        (dates (weekdays (dates days)))
        (status (query-rows sql3 "select date,mac from mac_addrs group by date")))
       (with-output-to-string
        (lambda ()
          (display "<p>課題はやってこない大学にも来ないじゃ救いようない。</p>")
          (display "<table>")
          (display "<tr><th></th>")
          (for ([u users])
            (let ((name (wifi->name u)))
              (display (format "<td><a href='/user/~a'>~a</a>|</td>"
                               name
                               (j name)))))
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
          (display "</table>")))))


(get "/list-all"
     (lambda (req)
       (html
        (list-days 400))))

(get "/list"
     (lambda (req)
       (html
        (list-days 30))))

;; for debug only
(define r #f)
(get "/info"
     (lambda (req)
      (set! r req)
      (html
        (format "<p>WIO_DB: ~a</p>" (getenv "WIO_DB"))
        (format "<p>WIO_SUBNET: ~a</p>" (getenv "WIO_SUBNET"))
        (format "<p>x-real-ip: ~a</p>" (x-real-ip req)))))

;;
;; start server
;;
(displayln "start at 8000/tcp")
(run #:listen-ip "127.0.0.1" #:port 8000)
;; for debug
;;(run #:listen-ip #f #:port 8000)
