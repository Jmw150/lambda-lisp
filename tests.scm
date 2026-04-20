(load "lib.scm")

(define failures '())

(define (record-failure! label actual expected)
  (set! failures (cons (list label actual expected) failures)))

(define (check-equal label actual expected)
  (unless (equal? actual expected)
    (record-failure! label actual expected)))

(define (check-true label actual)
  (unless actual
    (record-failure! label actual #t)))

(define (check-error label thunk)
  (let ((raised? (handle-exceptions exn
                   #t
                   (thunk)
                   #f)))
    (unless raised?
      (record-failure! label 'no-error 'error))))

(define env (make-global-env))

(check-equal "arithmetic"
             (run-string "(+ 1 2 3 4)" env)
             10)

(check-equal "define variable"
             (run-string "(begin (define x 41) (+ x 1))" env)
             42)

(check-equal "lambda application"
             (run-string "((lambda (x y) (+ x y)) 10 5)" env)
             15)

(check-equal "function define sugar"
             (run-string "(begin (define (square n) (* n n)) (square 9))" env)
             81)

(check-equal "if"
             (run-string "(if (> 5 2) 'yes 'no)" env)
             'yes)

(check-equal "closures"
             (run-string
              "(begin
                 (define (make-adder x) (lambda (y) (+ x y)))
                 (define add10 (make-adder 10))
                 (add10 7))"
              env)
             17)

(check-equal "mutation"
             (run-string "(begin (define total 1) (set! total (+ total 8)) total)" env)
             9)

(check-equal "let"
             (run-string "(let ((a 2) (b 5)) (+ a b))" env)
             7)

(check-equal "list primitives"
             (run-string "(car (cdr (list 1 2 3)))" env)
             2)

(check-equal "apply"
             (run-string "(apply + (list 4 5 6))" env)
             15)

(check-equal "stlc type identity"
             (run-string "(stlc-type '(lambda ((x Bool)) x))" env)
             '(-> Bool Bool))

(check-equal "stlc eval identity"
             (run-string "(stlc-eval '((lambda ((x Bool)) x) true))" env)
             'true)

(check-equal "stlc nat program"
             (run-string "(stlc-eval '((lambda ((x Nat)) (succ (succ x))) 3))" env)
             5)

(check-equal "stlc if and iszero"
             (run-string "(stlc-eval '(if (iszero (pred 1)) true false))" env)
             'true)

(check-true "stlc check"
            (run-string "(stlc-check '((lambda ((x Nat)) (succ x)) 2) 'Nat)" env))

(check-error "stlc type error"
             (lambda ()
               (run-string "(stlc-eval '((lambda ((x Bool)) x) 1))" env)))

(check-equal "cube polymorphic identity type"
             (run-string "(cube-type '(lambda ((A Type)) (lambda ((x A)) x)))" env)
             '(Pi ((A Type)) (-> A A)))

(check-equal "cube polymorphic identity eval"
             (run-string "(cube-eval '(((lambda ((A Type)) (lambda ((x A)) x)) Nat) 4))" env)
             4)

(check-equal "cube normalize beta at type level"
             (run-string "(cube-normalize '((lambda ((A Type)) A) Bool))" env)
             'Bool)

(check-equal "cube dependent pi normal form"
             (run-string "(cube-normalize '((lambda ((A Type)) (Pi ((x A)) A)) Bool))" env)
             '(-> Bool Bool))

(check-true "cube annotation check"
            (run-string "(cube-check '(the (lambda ((x Bool)) x) (-> Bool Bool)) '(-> Bool Bool))" env))

(check-equal "cube higher-order type"
             (run-string "(cube-type '(lambda ((F (-> Type Type))) (F Bool)))" env)
             '(-> (-> Type Type) Type))

(check-error "cube bad application"
             (lambda ()
               (run-string "(cube-eval '((lambda ((x Bool)) x) 0))" env)))

(check-error "cube bad annotation"
             (lambda ()
               (run-string "(cube-type '(the true Nat))" env)))

(check-equal "proof library loads"
             (run-string "(begin (load-file \"proofs.scm\") (cube-proof-names))" env)
             '(identity
               const
               compose
               flip
               apply
               twice
               bool-not
               double-not
               succ-preserves-nat
               type-level-map))

(check-equal "proof library validates"
             (run-string "(begin (load-file \"proofs.scm\") (cube-check-all-proofs))" env)
             'proof-library-ok)

(check-equal "proof proposition lookup"
             (run-string "(begin (load-file \"proofs.scm\") (cube-proof-proposition 'compose))" env)
             '(Pi ((A Type))
                (Pi ((B Type))
                  (Pi ((C Type))
                    (-> (-> B C) (-> (-> A B) (-> A C)))))))

(check-equal "proof term lookup"
             (run-string "(begin (load-file \"proofs.scm\") (cube-proof-term 'identity))" env)
             '(lambda ((A Type))
                (lambda ((x A))
                  x)))

(if (null? failures)
    (begin
      (display "All tests passed.\n")
      (exit 0))
    (begin
      (for-each
       (lambda (failure)
         (display "FAIL ")
         (display (car failure))
         (display ": expected ")
         (write (caddr failure))
         (display ", got ")
         (write (cadr failure))
         (newline))
       (reverse failures))
      (exit 1)))
