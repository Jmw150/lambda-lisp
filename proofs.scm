; A small proof library for the lambda-cube-style core.
;
; This file is written in the host Lisp implemented by this project, so it
; deliberately avoids any helpers that the host language does not provide.
;
; Each proof entry is stored as a 4-element list:
;
;   (name proposition proof explanation)
;
; where `proposition` and `proof` are quoted cube terms.

(define (proof-entry name proposition proof explanation)
  (list name proposition proof explanation))

(define (proof-name entry)
  (list-ref entry 0))

(define (proof-proposition entry)
  (list-ref entry 1))

(define (proof-term entry)
  (list-ref entry 2))

(define (proof-explanation entry)
  (list-ref entry 3))

(define (check-proof-entry entry)
  (cube-check (proof-term entry) (proof-proposition entry)))

(define (check-proof-library entries)
  (if (null? entries)
      'proof-library-ok
      (begin
        (check-proof-entry (car entries))
        (check-proof-library (cdr entries)))))

(define (proof-names entries)
  (if (null? entries)
      '()
      (cons (proof-name (car entries))
            (proof-names (cdr entries)))))

(define (find-proof entries target)
  (if (null? entries)
      false
      (if (eq? (proof-name (car entries)) target)
          (car entries)
          (find-proof (cdr entries) target))))

; 1. Identity: from A derive A.
(define proof:id
  (proof-entry
   'identity
   '(Pi ((A Type)) (-> A A))
   '(lambda ((A Type))
      (lambda ((x A))
        x))
   "Given a type A and a proof x : A, return x unchanged."))

; 2. K combinator / first projection: from A and B derive A.
(define proof:const
  (proof-entry
   'const
   '(Pi ((A Type)) (Pi ((B Type)) (-> A (-> B A))))
   '(lambda ((A Type))
      (lambda ((B Type))
        (lambda ((x A))
          (lambda ((y B))
            x))))
   "If A holds, then B is irrelevant for concluding A."))

; 3. Function composition: (B -> C) -> (A -> B) -> A -> C.
(define proof:compose
  (proof-entry
   'compose
   '(Pi ((A Type))
      (Pi ((B Type))
        (Pi ((C Type))
          (-> (-> B C) (-> (-> A B) (-> A C))))))
   '(lambda ((A Type))
      (lambda ((B Type))
        (lambda ((C Type))
          (lambda ((f (-> B C)))
            (lambda ((g (-> A B)))
              (lambda ((x A))
                (f (g x))))))))
   "Composition says proofs can be chained: A implies B and B implies C, so A implies C."))

; 4. Argument swap: (A -> B -> C) -> B -> A -> C.
(define proof:flip
  (proof-entry
   'flip
   '(Pi ((A Type))
      (Pi ((B Type))
        (Pi ((C Type))
          (-> (-> A (-> B C)) (-> B (-> A C))))))
   '(lambda ((A Type))
      (lambda ((B Type))
        (lambda ((C Type))
          (lambda ((f (-> A (-> B C))))
            (lambda ((y B))
              (lambda ((x A))
                ((f x) y)))))))
   "A proof of A -> B -> C can be rearranged into a proof of B -> A -> C by reordering arguments."))

; 5. Apply / modus ponens in functional form: (A -> B) -> A -> B.
(define proof:apply
  (proof-entry
   'apply
   '(Pi ((A Type)) (Pi ((B Type)) (-> (-> A B) (-> A B))))
   '(lambda ((A Type))
      (lambda ((B Type))
        (lambda ((f (-> A B)))
          (lambda ((x A))
            (f x)))))
   "This is modus ponens packaged as a term: feed a proof of A into a proof of A -> B."))

; 6. Double application of an endomorphism.
(define proof:twice
  (proof-entry
   'twice
   '(Pi ((A Type)) (-> (-> A A) (-> A A)))
   '(lambda ((A Type))
      (lambda ((f (-> A A)))
        (lambda ((x A))
          (f (f x)))))
   "Any endomorphism on A can be applied twice, yielding another endomorphism on A."))

; 7. Church-style negation over the built-in Bool.
(define proof:not
  (proof-entry
   'bool-not
   '(-> Bool Bool)
   '(lambda ((b Bool))
      (if b false true))
   "Negation on Bool is a direct computational proof/program."))

; 8. Double negation as a concrete computation on Bool.
(define proof:double-not
  (proof-entry
   'double-not
   '(-> Bool Bool)
   '(lambda ((b Bool))
      ((lambda ((n (-> Bool Bool)))
         (n (n b)))
       (lambda ((x Bool))
         (if x false true))))
   "This computes double negation at Bool; normalize it on true and false to inspect the behavior."))

; 9. Successor preserves Nat.
(define proof:succ-preserves-nat
  (proof-entry
   'succ-preserves-nat
   '(-> Nat Nat)
   '(lambda ((n Nat))
      (succ n))
   "A tiny example showing ordinary data constructors as proof-producing programs."))

; 10. A polymorphic self-map on type constructors.
(define proof:type-level-map
  (proof-entry
   'type-level-map
   '(-> (-> Type Type) (-> Type Type))
   '(lambda ((F (-> Type Type)))
      (lambda ((A Type))
        (F A)))
   "This is a simple example of the type-to-type corner of the cube."))

(define cube-proof-library
  (list proof:id
        proof:const
        proof:compose
        proof:flip
        proof:apply
        proof:twice
        proof:not
        proof:double-not
        proof:succ-preserves-nat
        proof:type-level-map))

(define (cube-proof-names)
  (proof-names cube-proof-library))

(define (cube-proof-by-name name)
  (find-proof cube-proof-library name))

(define (cube-show-proof name)
  (let ((entry (cube-proof-by-name name)))
    (if entry
        (list
         (list 'name (proof-name entry))
         (list 'proposition (proof-proposition entry))
         (list 'proof (proof-term entry))
         (list 'explanation (proof-explanation entry)))
        false)))

(define (cube-proof-proposition name)
  (let ((entry (cube-proof-by-name name)))
    (if entry
        (proof-proposition entry)
        false)))

(define (cube-proof-term name)
  (let ((entry (cube-proof-by-name name)))
    (if entry
        (proof-term entry)
        false)))

(define (cube-check-all-proofs)
  (check-proof-library cube-proof-library))
