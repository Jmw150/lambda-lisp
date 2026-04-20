(import scheme
        (chicken base)
        (chicken condition)
        (chicken format)
        (chicken io)
        (chicken port)
        (chicken process-context))

(define (make-env parent)
  (vector 'env parent '()))

(define (env-parent env)
  (vector-ref env 1))

(define (env-bindings env)
  (vector-ref env 2))

(define (env-set-bindings! env bindings)
  (vector-set! env 2 bindings))

(define (env-find-cell env symbol)
  (let loop ((current env))
    (if (not current)
        #f
        (let ((cell (assq symbol (env-bindings current))))
          (if cell
              cell
              (loop (env-parent current)))))))

(define (env-define! env symbol value)
  (let ((cell (assq symbol (env-bindings env))))
    (if cell
        (set-cdr! cell value)
        (env-set-bindings! env
                           (cons (cons symbol value) (env-bindings env)))))
  value)

(define (env-set! env symbol value)
  (let ((cell (env-find-cell env symbol)))
    (if cell
        (begin
          (set-cdr! cell value)
          value)
        (error (sprintf "unbound variable: ~a" symbol)))))

(define (env-ref env symbol)
  (let ((cell (env-find-cell env symbol)))
    (if cell
        (cdr cell)
        (error (sprintf "unbound variable: ~a" symbol)))))

(define (make-primitive name fn)
  (vector 'primitive name fn))

(define (primitive? value)
  (and (vector? value)
       (= (vector-length value) 3)
       (eq? (vector-ref value 0) 'primitive)))

(define (primitive-fn value)
  (vector-ref value 2))

(define (make-closure params body env)
  (vector 'closure params body env))

(define (closure? value)
  (and (vector? value)
       (= (vector-length value) 4)
       (eq? (vector-ref value 0) 'closure)))

(define (closure-params value)
  (vector-ref value 1))

(define (closure-body value)
  (vector-ref value 2))

(define (closure-env value)
  (vector-ref value 3))

(define (truthy? value)
  (not (eq? value #f)))

(define (proper-list-of-symbols? value)
  (or (null? value)
      (and (pair? value)
           (symbol? (car value))
           (proper-list-of-symbols? (cdr value)))))

(define (ensure-arity name args expected)
  (if (= (length args) expected)
      #t
      (error (sprintf "~a expected ~a arguments, got ~a"
                      name
                      expected
                      (length args)))))

(define (ensure-min-arity name args minimum)
  (if (>= (length args) minimum)
      #t
      (error (sprintf "~a expected at least ~a arguments, got ~a"
                      name
                      minimum
                      (length args)))))

(define (eval-sequence body env)
  (if (null? body)
      '()
      (let loop ((forms body))
        (let ((value (eval-expr (car forms) env)))
          (if (null? (cdr forms))
              value
              (loop (cdr forms)))))))

(define (zip-bindings params args)
  (if (null? params)
      '()
      (cons (cons (car params) (car args))
            (zip-bindings (cdr params) (cdr args)))))

(define (extend-env parent params args)
  (let ((env (make-env parent)))
    (let loop ((bindings (zip-bindings params args)))
      (if (null? bindings)
          env
          (begin
            (env-define! env (caar bindings) (cdar bindings))
            (loop (cdr bindings)))))))

(define (self-evaluating? expr)
  (or (number? expr)
      (string? expr)
      (boolean? expr)
      (char? expr)
      (null? expr)))

(define (eval-let expr env)
  (if (and (pair? (cdr expr)) (pair? (cddr expr)))
      (let ((bindings (cadr expr))
            (body (cddr expr)))
        (if (list? bindings)
            (let loop ((pairs bindings) (params '()) (args '()))
              (if (null? pairs)
                  (let ((closure (make-closure (reverse params) body env)))
                    (apply-value closure (reverse args)))
                  (let ((binding (car pairs)))
                    (if (and (pair? binding)
                             (pair? (cdr binding))
                             (null? (cddr binding))
                             (symbol? (car binding)))
                        (loop (cdr pairs)
                              (cons (car binding) params)
                              (cons (eval-expr (cadr binding) env) args))
                        (error "let bindings must be (name expr) pairs")))))
            (error "let requires a list of bindings")))
      (error "let requires bindings and a body")))

(define (eval-define expr env)
  (if (pair? (cdr expr))
      (let ((target (cadr expr))
            (rest (cddr expr)))
        (cond
          ((symbol? target)
           (ensure-arity 'define rest 1)
           (env-define! env target (eval-expr (car rest) env)))
          ((and (pair? target)
                (symbol? (car target))
                (proper-list-of-symbols? (cdr target)))
           (if (null? rest)
               (error "function define requires a body")
               (env-define! env
                            (car target)
                            (make-closure (cdr target) rest env))))
          (else
            (error "invalid define form"))))
      (error "define requires a target and a value")))

(define (eval-lambda expr env)
  (if (and (pair? (cdr expr)) (pair? (cddr expr)))
      (let ((params (cadr expr))
            (body (cddr expr)))
        (if (proper-list-of-symbols? params)
            (make-closure params body env)
            (error "lambda parameters must be a list of symbols")))
      (error "lambda requires parameters and a body")))

(define (eval-if expr env)
  (if (and (pair? (cdr expr)) (pair? (cddr expr)) (pair? (cdddr expr)))
      (if (truthy? (eval-expr (cadr expr) env))
          (eval-expr (caddr expr) env)
          (eval-expr (cadddr expr) env))
      (error "if requires test, then, and else expressions")))

(define (eval-set expr env)
  (if (and (pair? (cdr expr)) (pair? (cddr expr)) (null? (cdddr expr)))
      (let ((symbol (cadr expr))
            (value-expr (caddr expr)))
        (if (symbol? symbol)
            (env-set! env symbol (eval-expr value-expr env))
            (error "set! requires a symbol")))
      (error "set! requires a symbol and a value")))

(define (eval-application expr env)
  (let ((proc (eval-expr (car expr) env))
        (args (map (lambda (arg) (eval-expr arg env)) (cdr expr))))
    (apply-value proc args)))

(define (eval-expr expr env)
  (cond
    ((self-evaluating? expr) expr)
    ((symbol? expr) (env-ref env expr))
    ((pair? expr)
     (case (car expr)
       ((quote)
        (ensure-arity 'quote (cdr expr) 1)
        (cadr expr))
       ((if)
        (eval-if expr env))
       ((begin)
        (if (null? (cdr expr))
            '()
            (eval-sequence (cdr expr) env)))
       ((define)
        (eval-define expr env))
       ((set!)
        (eval-set expr env))
       ((lambda)
        (eval-lambda expr env))
       ((let)
        (eval-let expr env))
       (else
         (eval-application expr env))))
    (else
      (error (sprintf "cannot evaluate expression: ~S" expr)))))

(define (apply-value proc args)
  (cond
    ((primitive? proc)
     ((primitive-fn proc) args))
    ((closure? proc)
     (let ((params (closure-params proc)))
       (if (= (length params) (length args))
           (eval-sequence (closure-body proc)
                          (extend-env (closure-env proc) params args))
           (error (sprintf "closure expected ~a arguments, got ~a"
                           (length params)
                           (length args))))))
    (else
      (error (sprintf "attempted to call non-function: ~S" proc)))))

(define (numeric-fold op initial rest)
  (let loop ((remaining rest) (acc initial))
    (if (null? remaining)
        acc
        (loop (cdr remaining) (op acc (car remaining))))))

(define (primitive-sub args)
  (ensure-min-arity '- args 1)
  (if (null? (cdr args))
      (- (car args))
      (numeric-fold - (car args) (cdr args))))

(define (primitive-div args)
  (ensure-min-arity '/ args 1)
  (if (null? (cdr args))
      (/ 1 (car args))
      (numeric-fold / (car args) (cdr args))))

(define (comparison-chain name op args)
  (ensure-min-arity name args 2)
  (let loop ((left (car args)) (rest (cdr args)))
    (if (null? rest)
        #t
        (and (op left (car rest))
             (loop (car rest) (cdr rest))))))

(define (unary-primitive name fn args)
  (ensure-arity name args 1)
  (fn (car args)))

(define (binary-primitive name fn args)
  (ensure-arity name args 2)
  (fn (car args) (cadr args)))

(define (primitive-list-ref args)
  (ensure-arity 'list-ref args 2)
  (list-ref (car args) (cadr args)))

(define (primitive-apply args)
  (ensure-arity 'apply args 2)
  (apply-value (car args) (cadr args)))

(define (primitive-display args)
  (for-each display args)
  (newline)
  'ok)

;; ---------------------------------------------------------------------
;; A tiny pedagogical "lambda cube style" core
;;
;; The goal here is readability over completeness.  We keep the surface
;; syntax as quoted s-expressions, parse it into a very small internal
;; language, and then define:
;;
;; 1. capture-avoiding substitution
;; 2. normalization
;; 3. definitional equality via normalization + alpha-equivalence
;; 4. type inference/checking
;;
;; Supported surface syntax:
;;
;;   Type
;;   Bool | true | false | (if c t e)
;;   Nat  | 0 | 1 | ... | (succ n) | (pred n) | (iszero n)
;;   (lambda ((x A)) body)
;;   (Pi ((x A)) B)
;;   (-> A B)                  ; sugar for a non-dependent Pi
;;   (the expr type)           ; explicit annotation
;;   (f a) / (f a b c)         ; left-associated application
;;
;; This is intentionally a single-universe teaching core, so we accept
;; Type : Type.  That is inconsistent as a foundation, but it keeps the
;; implementation and the explanations much smaller.
;; ---------------------------------------------------------------------

(define cube-fresh-counter 0)

(define (cube-context-ref ctx symbol)
  (let ((cell (assq symbol ctx)))
    (if cell
        (cdr cell)
        (error (sprintf "unbound cube variable: ~a" symbol)))))

(define (cube-lambda? expr)
  (and (pair? expr) (eq? (car expr) 'lambda)))

(define (cube-pi? expr)
  (and (pair? expr) (eq? (car expr) 'Pi)))

(define (cube-app? expr)
  (and (pair? expr) (eq? (car expr) 'app)))

(define (cube-ann? expr)
  (and (pair? expr) (eq? (car expr) 'the)))

(define (cube-if? expr)
  (and (pair? expr) (eq? (car expr) 'if)))

(define (cube-unary-form? name expr)
  (and (pair? expr) (eq? (car expr) name)))

(define (cube-constant-symbol? expr)
  (and (symbol? expr)
       (memq expr '(Type Bool Nat true false))))

(define (cube-parameter-binding params who)
  (if (and (pair? params) (null? (cdr params)))
      (let ((binding (car params)))
        (if (and (pair? binding)
                 (pair? (cdr binding))
                 (null? (cddr binding))
                 (symbol? (car binding)))
            binding
            (error (sprintf "~a bindings must look like ((name Type))" who))))
      (error (sprintf "~a expects exactly one typed binder" who))))

(define (cube-left-associated-application terms)
  (if (null? (cdr terms))
      (car terms)
      (cube-left-associated-application
       (cons (list 'app (car terms) (cadr terms))
             (cddr terms)))))

(define (parse-cube-term datum)
  (cond
    ((or (symbol? datum)
         (and (integer? datum) (>= datum 0)))
     datum)
    ((pair? datum)
     (case (car datum)
       ((lambda)
        (let ((binding (cube-parameter-binding (cadr datum) 'lambda)))
          (unless (and (pair? (cdr datum))
                       (pair? (cddr datum))
                       (null? (cdddr datum)))
            (error "lambda expects a binder list and a body"))
          (list 'lambda
                (car binding)
                (parse-cube-term (cadr binding))
                (parse-cube-term (caddr datum)))))
       ((Pi)
        (let ((binding (cube-parameter-binding (cadr datum) 'Pi)))
          (unless (and (pair? (cdr datum))
                       (pair? (cddr datum))
                       (null? (cdddr datum)))
            (error "Pi expects a binder list and a body"))
          (list 'Pi
                (car binding)
                (parse-cube-term (cadr binding))
                (parse-cube-term (caddr datum)))))
       ((->)
        (unless (and (pair? (cdr datum))
                     (pair? (cddr datum))
                     (null? (cdddr datum)))
          (error "-> expects exactly two arguments"))
        (list 'Pi '_
              (parse-cube-term (cadr datum))
              (parse-cube-term (caddr datum))))
       ((the)
        (unless (and (pair? (cdr datum))
                     (pair? (cddr datum))
                     (null? (cdddr datum)))
          (error "the expects an expression and a type"))
        (list 'the
              (parse-cube-term (cadr datum))
              (parse-cube-term (caddr datum))))
       ((if)
        (unless (and (pair? (cdr datum))
                     (pair? (cddr datum))
                     (pair? (cdddr datum))
                     (null? (cddddr datum)))
          (error "if expects condition, then branch, and else branch"))
        (list 'if
              (parse-cube-term (cadr datum))
              (parse-cube-term (caddr datum))
              (parse-cube-term (cadddr datum))))
       ((succ pred iszero)
        (unless (and (pair? (cdr datum))
                     (null? (cddr datum)))
          (error (sprintf "~a expects one argument" (car datum))))
        (list (car datum) (parse-cube-term (cadr datum))))
       (else
        (if (and (list? datum) (>= (length datum) 2))
            (cube-left-associated-application (map parse-cube-term datum))
            (error (sprintf "invalid cube syntax: ~S" datum))))))
    (else
      (error (sprintf "unsupported cube datum: ~S" datum)))))

(define (cube-free-vars expr)
  (cond
    ((and (symbol? expr) (not (cube-constant-symbol? expr)))
     (list expr))
    ((or (cube-constant-symbol? expr)
         (and (integer? expr) (>= expr 0)))
     '())
    ((cube-lambda? expr)
     (append (cube-free-vars (caddr expr))
             (let loop ((vars (cube-free-vars (cadddr expr))) (out '()))
               (if (null? vars)
                   (reverse out)
                   (if (eq? (car vars) (cadr expr))
                       (loop (cdr vars) out)
                       (loop (cdr vars) (cons (car vars) out)))))))
    ((cube-pi? expr)
     (append (cube-free-vars (caddr expr))
             (let loop ((vars (cube-free-vars (cadddr expr))) (out '()))
               (if (null? vars)
                   (reverse out)
                   (if (eq? (car vars) (cadr expr))
                       (loop (cdr vars) out)
                       (loop (cdr vars) (cons (car vars) out)))))))
    ((cube-app? expr)
     (append (cube-free-vars (cadr expr))
             (cube-free-vars (caddr expr))))
    ((cube-ann? expr)
     (append (cube-free-vars (cadr expr))
             (cube-free-vars (caddr expr))))
    ((cube-if? expr)
     (append (cube-free-vars (cadr expr))
             (cube-free-vars (caddr expr))
             (cube-free-vars (cadddr expr))))
    ((cube-unary-form? 'succ expr)
     (cube-free-vars (cadr expr)))
    ((cube-unary-form? 'pred expr)
     (cube-free-vars (cadr expr)))
    ((cube-unary-form? 'iszero expr)
     (cube-free-vars (cadr expr)))
    (else
      '())))

(define (cube-fresh-symbol base forbidden)
  (let loop ()
    (set! cube-fresh-counter (+ cube-fresh-counter 1))
    (let* ((stem (symbol->string base))
           (candidate (string->symbol
                       (sprintf "~a#~a" stem cube-fresh-counter))))
      (if (memq candidate forbidden)
          (loop)
          candidate))))

(define (cube-substitute expr var replacement)
  (cond
    ((symbol? expr)
     (if (eq? expr var) replacement expr))
    ((and (integer? expr) (>= expr 0))
     expr)
    ((cube-lambda? expr)
     (let* ((binder (cadr expr))
            (binder-type (cube-substitute (caddr expr) var replacement))
            (body (cadddr expr)))
       (cond
         ((eq? binder var)
          (list 'lambda binder binder-type body))
         ((memq binder (cube-free-vars replacement))
          (let* ((fresh (cube-fresh-symbol binder
                                           (append (cube-free-vars body)
                                                   (cube-free-vars replacement)
                                                   (list var))))
                 (renamed-body (cube-substitute body binder fresh)))
            (list 'lambda
                  fresh
                  binder-type
                  (cube-substitute renamed-body var replacement))))
         (else
          (list 'lambda binder binder-type
                (cube-substitute body var replacement))))))
    ((cube-pi? expr)
     (let* ((binder (cadr expr))
            (domain (cube-substitute (caddr expr) var replacement))
            (codomain (cadddr expr)))
       (cond
         ((eq? binder var)
          (list 'Pi binder domain codomain))
         ((memq binder (cube-free-vars replacement))
          (let* ((fresh (cube-fresh-symbol binder
                                           (append (cube-free-vars codomain)
                                                   (cube-free-vars replacement)
                                                   (list var))))
                 (renamed-codomain (cube-substitute codomain binder fresh)))
            (list 'Pi
                  fresh
                  domain
                  (cube-substitute renamed-codomain var replacement))))
         (else
          (list 'Pi binder domain
                (cube-substitute codomain var replacement))))))
    ((cube-app? expr)
     (list 'app
           (cube-substitute (cadr expr) var replacement)
           (cube-substitute (caddr expr) var replacement)))
    ((cube-ann? expr)
     (list 'the
           (cube-substitute (cadr expr) var replacement)
           (cube-substitute (caddr expr) var replacement)))
    ((cube-if? expr)
     (list 'if
           (cube-substitute (cadr expr) var replacement)
           (cube-substitute (caddr expr) var replacement)
           (cube-substitute (cadddr expr) var replacement)))
    ((cube-unary-form? 'succ expr)
     (list 'succ (cube-substitute (cadr expr) var replacement)))
    ((cube-unary-form? 'pred expr)
     (list 'pred (cube-substitute (cadr expr) var replacement)))
    ((cube-unary-form? 'iszero expr)
     (list 'iszero (cube-substitute (cadr expr) var replacement)))
    (else
      expr)))

(define (cube-normalize expr)
  (cond
    ((or (cube-constant-symbol? expr)
         (and (integer? expr) (>= expr 0))
         (and (symbol? expr) (not (cube-constant-symbol? expr))))
     expr)
    ((cube-lambda? expr)
     (list 'lambda
           (cadr expr)
           (cube-normalize (caddr expr))
           (cube-normalize (cadddr expr))))
    ((cube-pi? expr)
     (list 'Pi
           (cadr expr)
           (cube-normalize (caddr expr))
           (cube-normalize (cadddr expr))))
    ((cube-ann? expr)
     (cube-normalize (cadr expr)))
    ((cube-if? expr)
     (let ((test (cube-normalize (cadr expr))))
       (cond
         ((eq? test 'true) (cube-normalize (caddr expr)))
         ((eq? test 'false) (cube-normalize (cadddr expr)))
         (else
          (list 'if test
                (cube-normalize (caddr expr))
                (cube-normalize (cadddr expr)))))))
    ((cube-unary-form? 'succ expr)
     (let ((value (cube-normalize (cadr expr))))
       (if (and (integer? value) (>= value 0))
           (+ value 1)
           (list 'succ value))))
    ((cube-unary-form? 'pred expr)
     (let ((value (cube-normalize (cadr expr))))
       (if (and (integer? value) (>= value 0))
           (if (zero? value) 0 (- value 1))
           (list 'pred value))))
    ((cube-unary-form? 'iszero expr)
     (let ((value (cube-normalize (cadr expr))))
       (if (and (integer? value) (>= value 0))
           (if (zero? value) 'true 'false)
           (list 'iszero value))))
    ((cube-app? expr)
     (let ((fn (cube-normalize (cadr expr)))
           (arg (cube-normalize (caddr expr))))
       (if (cube-lambda? fn)
           (cube-normalize (cube-substitute (cadddr fn) (cadr fn) arg))
           (list 'app fn arg))))
    (else
      expr)))

(define (cube-alpha-equal? left right env)
  (cond
    ((and (symbol? left) (symbol? right))
     (let ((cell (assq left env)))
       (if cell
           (eq? (cdr cell) right)
           (eq? left right))))
    ((and (integer? left) (integer? right))
     (= left right))
    ((and (cube-lambda? left) (cube-lambda? right))
     (and (cube-alpha-equal? (caddr left) (caddr right) env)
          (cube-alpha-equal? (cadddr left)
                             (cadddr right)
                             (cons (cons (cadr left) (cadr right)) env))))
    ((and (cube-pi? left) (cube-pi? right))
     (and (cube-alpha-equal? (caddr left) (caddr right) env)
          (cube-alpha-equal? (cadddr left)
                             (cadddr right)
                             (cons (cons (cadr left) (cadr right)) env))))
    ((and (cube-app? left) (cube-app? right))
     (and (cube-alpha-equal? (cadr left) (cadr right) env)
          (cube-alpha-equal? (caddr left) (caddr right) env)))
    ((and (cube-ann? left) (cube-ann? right))
     (and (cube-alpha-equal? (cadr left) (cadr right) env)
          (cube-alpha-equal? (caddr left) (caddr right) env)))
    ((and (cube-if? left) (cube-if? right))
     (and (cube-alpha-equal? (cadr left) (cadr right) env)
          (cube-alpha-equal? (caddr left) (caddr right) env)
          (cube-alpha-equal? (cadddr left) (cadddr right) env)))
    ((and (cube-unary-form? 'succ left) (cube-unary-form? 'succ right))
     (cube-alpha-equal? (cadr left) (cadr right) env))
    ((and (cube-unary-form? 'pred left) (cube-unary-form? 'pred right))
     (cube-alpha-equal? (cadr left) (cadr right) env))
    ((and (cube-unary-form? 'iszero left) (cube-unary-form? 'iszero right))
     (cube-alpha-equal? (cadr left) (cadr right) env))
    (else
      (equal? left right))))

(define (cube-defeq? left right)
  (cube-alpha-equal? (cube-normalize left) (cube-normalize right) '()))

(define (cube-expect-type! ctx expr)
  (let ((ty (cube-infer ctx expr)))
    (unless (cube-defeq? ty 'Type)
      (error (sprintf "expected a type, but inferred ~S"
                      (unparse-cube-term ty))))
    ty))

(define (cube-check ctx expr expected)
  (let ((goal (cube-normalize expected)))
    (if (and (cube-lambda? expr) (cube-pi? goal))
        (begin
          (unless (cube-defeq? (caddr expr) (caddr goal))
            (error (sprintf "lambda binder annotation ~S does not match expected domain ~S"
                            (unparse-cube-term (caddr expr))
                            (unparse-cube-term (caddr goal)))))
          (cube-expect-type! ctx (caddr expr))
          (cube-check (cons (cons (cadr expr) (caddr expr)) ctx)
                      (cadddr expr)
                      (cube-substitute (cadddr goal) (cadr goal) (cadr expr))))
        (let ((actual (cube-infer ctx expr)))
          (unless (cube-defeq? actual goal)
            (error (sprintf "type mismatch: expected ~S, got ~S"
                            (unparse-cube-term goal)
                            (unparse-cube-term actual))))))))

(define (cube-infer ctx expr)
  (cond
    ((eq? expr 'Type) 'Type)
    ((or (eq? expr 'Bool) (eq? expr 'Nat)) 'Type)
    ((or (eq? expr 'true) (eq? expr 'false)) 'Bool)
    ((and (integer? expr) (>= expr 0)) 'Nat)
    ((symbol? expr) (cube-context-ref ctx expr))
    ((cube-ann? expr)
     (let ((term (cadr expr))
           (ann (caddr expr)))
       (cube-expect-type! ctx ann)
       (cube-check ctx term ann)
       ann))
    ((cube-lambda? expr)
     (let ((binder (cadr expr))
           (domain (caddr expr))
           (body (cadddr expr)))
       (cube-expect-type! ctx domain)
       (let ((body-type (cube-infer (cons (cons binder domain) ctx) body)))
         (list 'Pi binder domain body-type))))
    ((cube-pi? expr)
     (cube-expect-type! ctx (caddr expr))
     (cube-expect-type! (cons (cons (cadr expr) (caddr expr)) ctx)
                        (cadddr expr))
     'Type)
    ((cube-app? expr)
     (let* ((fn-type (cube-normalize (cube-infer ctx (cadr expr)))))
       (unless (cube-pi? fn-type)
         (error (sprintf "attempted to apply a non-function of type ~S"
                         (unparse-cube-term fn-type))))
       (cube-check ctx (caddr expr) (caddr fn-type))
       (cube-normalize
        (cube-substitute (cadddr fn-type) (cadr fn-type) (caddr expr)))))
    ((cube-if? expr)
     (cube-check ctx (cadr expr) 'Bool)
     (let ((then-type (cube-infer ctx (caddr expr))))
       (cube-check ctx (cadddr expr) then-type)
       then-type))
    ((cube-unary-form? 'succ expr)
     (cube-check ctx (cadr expr) 'Nat)
     'Nat)
    ((cube-unary-form? 'pred expr)
     (cube-check ctx (cadr expr) 'Nat)
     'Nat)
    ((cube-unary-form? 'iszero expr)
     (cube-check ctx (cadr expr) 'Nat)
     'Bool)
    (else
      (error (sprintf "cannot infer cube type for ~S"
                      (unparse-cube-term expr))))))

(define (unparse-cube-term expr)
  (cond
    ((or (symbol? expr)
         (and (integer? expr) (>= expr 0)))
     expr)
    ((cube-lambda? expr)
     (list 'lambda
           (list (list (cadr expr)
                       (unparse-cube-term (caddr expr))))
           (unparse-cube-term (cadddr expr))))
    ((cube-pi? expr)
     (if (not (memq (cadr expr) (cube-free-vars (cadddr expr))))
         (list '->
               (unparse-cube-term (caddr expr))
               (unparse-cube-term (cadddr expr)))
         (list 'Pi
               (list (list (cadr expr)
                           (unparse-cube-term (caddr expr))))
               (unparse-cube-term (cadddr expr)))))
    ((cube-app? expr)
     (list (unparse-cube-term (cadr expr))
           (unparse-cube-term (caddr expr))))
    ((cube-ann? expr)
     (list 'the
           (unparse-cube-term (cadr expr))
           (unparse-cube-term (caddr expr))))
    ((cube-if? expr)
     (list 'if
           (unparse-cube-term (cadr expr))
           (unparse-cube-term (caddr expr))
           (unparse-cube-term (cadddr expr))))
    ((cube-unary-form? 'succ expr)
     (list 'succ (unparse-cube-term (cadr expr))))
    ((cube-unary-form? 'pred expr)
     (list 'pred (unparse-cube-term (cadr expr))))
    ((cube-unary-form? 'iszero expr)
     (list 'iszero (unparse-cube-term (cadr expr))))
    (else
      expr)))

(define (cube-type-of-datum datum)
  (unparse-cube-term (cube-normalize (cube-infer '() (parse-cube-term datum)))))

(define (cube-normalize-datum datum)
  (let ((expr (parse-cube-term datum)))
    (cube-infer '() expr)
    (unparse-cube-term (cube-normalize expr))))

(define (cube-check-datum expr-datum type-datum)
  (let ((expr (parse-cube-term expr-datum))
        (expected (parse-cube-term type-datum)))
    (cube-expect-type! '() expected)
    (cube-check '() expr expected)
    #t))

(define (primitive-cube-type args)
  (ensure-arity 'cube-type args 1)
  (cube-type-of-datum (car args)))

(define (primitive-cube-normalize args)
  (ensure-arity 'cube-normalize args 1)
  (cube-normalize-datum (car args)))

(define (primitive-cube-eval args)
  (ensure-arity 'cube-eval args 1)
  (cube-normalize-datum (car args)))

(define (primitive-cube-check args)
  (ensure-arity 'cube-check args 2)
  (cube-check-datum (car args) (cadr args)))

;; Backward-compatible STLC wrappers.  The simply typed fragment is a
;; subset of the cube core, so these simply delegate to the new engine.
(define (primitive-stlc-type args)
  (primitive-cube-type args))

(define (primitive-stlc-check args)
  (primitive-cube-check args))

(define (primitive-stlc-eval args)
  (primitive-cube-eval args))

(define interaction-env #f)

(define (primitive-read-file args)
  (ensure-arity 'load-file args 1)
  (if interaction-env
      (call-with-input-file
          (car args)
        (lambda (port)
          (run-port port interaction-env)))
      (error "load-file is unavailable before the global environment is initialized")))

(define (install-primitives! env)
  (for-each
   (lambda (entry)
     (env-define! env (car entry) (cdr entry)))
   (list
    (cons '+ (make-primitive '+ (lambda (args) (apply + args))))
    (cons '- (make-primitive '- primitive-sub))
    (cons '* (make-primitive '* (lambda (args) (apply * args))))
    (cons '/ (make-primitive '/ primitive-div))
    (cons '= (make-primitive '= (lambda (args) (comparison-chain '= = args))))
    (cons '< (make-primitive '< (lambda (args) (comparison-chain '< < args))))
    (cons '<= (make-primitive '<= (lambda (args) (comparison-chain '<= <= args))))
    (cons '> (make-primitive '> (lambda (args) (comparison-chain '> > args))))
    (cons '>= (make-primitive '>= (lambda (args) (comparison-chain '>= >= args))))
    (cons 'cons (make-primitive 'cons (lambda (args) (binary-primitive 'cons cons args))))
    (cons 'car (make-primitive 'car (lambda (args) (unary-primitive 'car car args))))
    (cons 'cdr (make-primitive 'cdr (lambda (args) (unary-primitive 'cdr cdr args))))
    (cons 'list (make-primitive 'list (lambda (args) args)))
    (cons 'list-ref (make-primitive 'list-ref primitive-list-ref))
    (cons 'null? (make-primitive 'null? (lambda (args) (unary-primitive 'null? null? args))))
    (cons 'pair? (make-primitive 'pair? (lambda (args) (unary-primitive 'pair? pair? args))))
    (cons 'symbol? (make-primitive 'symbol? (lambda (args) (unary-primitive 'symbol? symbol? args))))
    (cons 'number? (make-primitive 'number? (lambda (args) (unary-primitive 'number? number? args))))
    (cons 'boolean? (make-primitive 'boolean? (lambda (args) (unary-primitive 'boolean? boolean? args))))
    (cons 'not (make-primitive 'not (lambda (args) (unary-primitive 'not not args))))
    (cons 'eq? (make-primitive 'eq? (lambda (args) (binary-primitive 'eq? eq? args))))
    (cons 'display (make-primitive 'display primitive-display))
    (cons 'apply (make-primitive 'apply primitive-apply))
    (cons 'cube-type (make-primitive 'cube-type primitive-cube-type))
    (cons 'cube-check (make-primitive 'cube-check primitive-cube-check))
    (cons 'cube-normalize (make-primitive 'cube-normalize primitive-cube-normalize))
    (cons 'cube-eval (make-primitive 'cube-eval primitive-cube-eval))
    (cons 'stlc-type (make-primitive 'stlc-type primitive-stlc-type))
    (cons 'stlc-check (make-primitive 'stlc-check primitive-stlc-check))
    (cons 'stlc-eval (make-primitive 'stlc-eval primitive-stlc-eval))
    (cons 'load-file (make-primitive 'load-file primitive-read-file))
    (cons 'true #t)
    (cons 'false #f))))

(define (make-global-env)
  (let ((env (make-env #f)))
    (set! interaction-env env)
    (install-primitives! env)
    env))

(define (write-result value)
  (unless (eq? value 'ok)
    (write value)
    (newline)))

(define (run-port port env)
  (let loop ((last '()))
    (let ((expr (read port)))
      (if (eof-object? expr)
          last
          (loop (eval-expr expr env))))))

(define (run-file path env)
  (call-with-input-file path
    (lambda (port)
      (run-port port env))))

(define (run-string text env)
  (with-input-from-string text
    (lambda ()
      (run-port (current-input-port) env))))

(define (repl env)
  (display "chicken-lisp> ")
  (flush-output)
  (handle-exceptions exn
    (begin
      (print-error-message exn)
      (repl env))
    (let ((expr (read)))
      (if (eof-object? expr)
          (newline)
          (begin
            (write-result (eval-expr expr env))
            (repl env))))))

(define (usage)
  (display "Usage: chicken-lisp [file]\n")
  (display "       chicken-lisp -e \"(expr ...)\"\n"))

(define (main args)
  (let ((env (make-global-env)))
    (cond
      ((null? args)
       (repl env))
      ((and (= (length args) 2) (string=? (car args) "-e"))
       (write-result (run-string (cadr args) env)))
      ((= (length args) 1)
       (write-result (run-file (car args) env)))
      (else
        (usage)
        (exit 1)))))
