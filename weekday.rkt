;; Author: Koki Miyakawa, 2019.
#lang racket
(provide day-of-week
         monday?
         tuesday?
         wednesday?
         thursday?
         friday?
         saturday?
         sunday?
         weekend?
         weekday?)

;2019/1/1 Tuesday 2
;(define RP '(2019 1 1 2))

(define (days month)
  (case month
    [(1 3 5 7 8 10 12) 31]
    [(4 6 9 11) 30]
    [(2) 28]
    [else 0]))

(define (leap? year)
  (and (zero? (modulo year 4))
       (not (and (zero? (modulo year 100))
                 (< 0 (modulo year 400))))))

(define (distance-y year)
  (cond
    ((<= 2019 year)
     (+ (* 365 (- year 2019))
        (length (filter leap? (range 2019 year)))))
    (else
     (- (* 365 (- year 2019))
        (length (filter leap? (range year 2019)))))))

(define (distance-d year month day)
  (+ day
     (apply + (map days (range 1 month)))
     (if (and (leap? year) (< 2 month)) 1 0)))

(define (aux ls)
  (let ((year (first ls))
        (month (second ls))
        (day (third ls)))
    (modulo (+ (distance-y year) (distance-d year month day) 1) 7)))

(define (day-of-week arg . args)
  (let ((arguments (flatten (cons arg args))))
    (if (= 1 (length arguments))
        (aux (map string->number
                (apply (lambda (x)
                          (string-split x "-")) arguments)))
        (aux arguments))))


(define (make-day? n)
  (lambda (arg . args)
    (let ((dow (day-of-week (flatten (cons arg args)))))
      (= dow n))))

(define monday? (make-day? 1))
(define tuesday? (make-day? 2))
(define wednesday? (make-day? 3))
(define thursday? (make-day? 4))
(define friday? (make-day? 5))
(define saturday? (make-day? 6))
(define sunday? (make-day? 0))

(define (weekend? arg . args)
  (let ((arguments (flatten (cons arg args))))
    (or (saturday? arguments)
         (sunday? arguments))))

(define (weekday? arg . args)
  (not (weekend? (cons arg args))))
