# coc-lisp

`coc-lisp` is a small Lisp interpreter in CHICKEN Scheme with a second,
deliberately separate typed core inspired by the Calculus of Constructions.

The project is meant to be readable first. It is not trying to be a production
Scheme, a full proof assistant, or a fully formal CoC kernel. Instead, it sits
in an interesting middle ground:

- a compact untyped Lisp evaluator with lexical scope and closures
- a quoted typed core with `Type`, `Pi`, normalization, and type checking
- a small proof library that can be loaded and re-checked from the host Lisp

That makes it useful both as a runnable toy Lisp and as an instructional
language project for typed lambda calculi.

## What The Project Contains

There are really two languages here.

### 1. Host Lisp

The host evaluator handles ordinary Lisp programs with:

- numbers, strings, booleans, characters, symbols, and lists
- lexical environments and mutable bindings
- special forms:
  - `quote`
  - `if`
  - `begin`
  - `define`
  - `set!`
  - `lambda`
  - `let`
- primitive procedures for:
  - arithmetic and comparisons
  - list construction and inspection
  - predicates
  - `apply`
  - simple output
  - file loading

### 2. Calculus-of-Constructions-Style Core

The typed subsystem is intentionally separate from the host evaluator.
You interact with it by passing quoted terms from Lisp.

The current core supports:

- `Type`
- `Bool`, `true`, `false`
- `Nat`, numeric literals, `succ`, `pred`, `iszero`
- functions via `lambda`
- dependent function types via `Pi`
- arrow sugar via `->`
- annotations via `the`
- normalization
- type inference and checking
- definitional equality by normalization plus alpha-equivalence

This is a teaching-oriented core, not a logically complete foundation. In
particular, it intentionally accepts `Type : Type` to keep the implementation
small and readable.

## Repository Layout

- [main.scm](./main.scm) is the executable entry point
- [lib.scm](./lib.scm) contains the interpreter, primitive environment, typed
  core, normalization, and type checker
- [proofs.scm](./proofs.scm) defines a small library of example proof terms
- [tests.scm](./tests.scm) contains regression tests for both the host Lisp and
  the typed core
- [LAMBDA-CUBE.md](./LAMBDA-CUBE.md) explains the design of the typed core in
  more detail
- [Makefile](./Makefile) builds and tests the project

## Build

The project uses CHICKEN Scheme.

Build the executable with:

```sh
make
```

This produces the `chicken-lisp` executable.

## Run

Start the REPL:

```sh
./chicken-lisp
```

Evaluate a single expression:

```sh
./chicken-lisp -e "(begin (define (fact n) (if (= n 0) 1 (* n (fact (- n 1))))) (fact 5))"
```

Run a file:

```sh
./chicken-lisp program.lisp
```

## Host Lisp Examples

A simple closure example:

```sh
./chicken-lisp -e "(begin
  (define (make-adder x) (lambda (y) (+ x y)))
  (define add10 (make-adder 10))
  (add10 7))"
```

A list-processing example:

```sh
./chicken-lisp -e "(car (cdr (list 1 2 3)))"
```

## Typed Core API

The main entry points from the host Lisp are:

- `cube-type`
- `cube-check`
- `cube-normalize`
- `cube-eval`

There are also backward-compatible wrappers for the older simply typed layer:

- `stlc-type`
- `stlc-check`
- `stlc-eval`

### Core Surface Syntax

The typed terms are written as quoted s-expressions.

Examples:

```scheme
'Type
'Bool
'Nat
'(lambda ((x Bool)) x)
'(Pi ((A Type)) (-> A A))
'((lambda ((x Nat)) (succ x)) 4)
'(the (lambda ((x Bool)) x) (-> Bool Bool))
```

### Typed Core Examples

Infer the type of polymorphic identity:

```sh
./chicken-lisp -e "(cube-type '(lambda ((A Type)) (lambda ((x A)) x)))"
```

Normalize a term:

```sh
./chicken-lisp -e "(cube-normalize '((lambda ((A Type)) A) Bool))"
```

Evaluate a closed typed term:

```sh
./chicken-lisp -e "(cube-eval '(((lambda ((A Type)) (lambda ((x A)) x)) Nat) 4))"
```

Check an annotation:

```sh
./chicken-lisp -e "(cube-check '(the (lambda ((x Bool)) x) (-> Bool Bool)) '(-> Bool Bool))"
```

## Proof Library

The file [proofs.scm](./proofs.scm) contains named example proof terms and
small derived constructions. Load it from the interpreter with:

```sh
./chicken-lisp -e "(begin (load-file \"proofs.scm\") (cube-proof-names))"
```

Useful helpers after loading:

- `cube-proof-names`
- `cube-show-proof`
- `cube-proof-proposition`
- `cube-proof-term`
- `cube-check-all-proofs`

Examples:

```sh
./chicken-lisp -e "(begin (load-file \"proofs.scm\") (cube-show-proof 'compose))"
./chicken-lisp -e "(begin (load-file \"proofs.scm\") (cube-check-all-proofs))"
```

## Test

Run the regression suite with:

```sh
make test
```

The tests cover:

- ordinary host Lisp evaluation
- closures, mutation, and list primitives
- simply typed compatibility helpers
- cube normalization and type checking
- proof library loading and validation

## Design Notes

Some of the most important design choices are intentional simplifications:

- the typed core is quoted data, not a second parser
- normalization and substitution are written directly in Scheme
- the host Lisp and typed core are kept separate on purpose
- the core is optimized for readability rather than metatheoretic strength
- the project uses a single-universe teaching shortcut instead of a proper
  universe hierarchy

That separation is especially important if the project grows. Effects and
system integration belong naturally in the host Lisp evaluator, while the typed
core can stay small and explanatory.

## Near-Term Roadmap

The main next features currently planned are:

- a foreign function interface for host-side interoperability
- Scheme-style macros

A fuller checklist lives in [TODO.md](./TODO.md).
