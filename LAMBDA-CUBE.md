# Small Lambda Cube Style Core

This project does not try to be a full implementation of the lambda cube in
all its historical and logical detail. Instead, it implements a very small
core language that is shaped like the lambda cube and is meant to be read by
students.

The code lives in `lib.scm`, but this document explains the design in prose.

## Design Goal

The main goal is readability.

That means the implementation prefers:

- quoted s-expression syntax instead of a custom parser
- one small internal language instead of many special cases
- normalization and substitution written directly in Scheme
- explicit comments and direct control flow

It does not try to be:

- logically complete
- optimized
- a proof assistant
- a replacement for Coq, Agda, Lean, or even a serious dependently typed kernel

## Why "Lambda Cube Style" Instead Of "Full Lambda Cube"?

The classical lambda cube organizes features around three ideas:

- terms may depend on types
- types may depend on types
- types may depend on terms

This interpreter gives us a single core where all of those ideas can be
discussed using one syntax:

- `lambda` introduces functions
- `Pi` introduces dependent function types
- `Type` lets us talk about types as first-class objects

That is enough to teach the central implementation ideas without forcing the
reader to carry around a larger formal system all at once.

## A Deliberate Simplification: `Type : Type`

The core accepts:

```scheme
Type
```

and treats `Type` itself as having type `Type`.

This is not a sound foundation for theorem proving. It is a teaching shortcut.
The upside is that the checker becomes much smaller and easier to follow.

If this project ever grows into a more serious kernel, the natural next step
would be replacing the single universe with a hierarchy such as `Type0`,
`Type1`, and so on.

## Surface Syntax

Terms are written as quoted Scheme data.

### Functions

```scheme
'(lambda ((x Bool)) x)
```

### Dependent function types

```scheme
'(Pi ((A Type)) (-> A A))
```

### Ordinary arrows

```scheme
'(-> Bool Bool)
```

Internally, `->` is just sugar for a `Pi` type whose binder is unused.

### Application

```scheme
'((lambda ((x Nat)) (succ x)) 4)
'(f a b c)
```

Multi-argument application is parsed as left-associated application.

### Type annotations

```scheme
'(the (lambda ((x Bool)) x) (-> Bool Bool))
```

### Base data

```scheme
'true
'false
'Bool
'Nat
'(succ 3)
'(iszero (pred 1))
```

## Internal Pipeline

The core works in four stages.

### 1. Parse

`parse-cube-term` translates quoted surface syntax into a tiny internal AST.

The parser is intentionally small. It mostly checks the shape of special forms
and turns ordinary lists into left-associated applications.

### 2. Substitute

`cube-substitute` performs capture-avoiding substitution.

This is the heart of the evaluator. When beta-reduction would capture a free
variable, the code generates a fresh symbol first and renames the binder.

### 3. Normalize

`cube-normalize` reduces terms to normal form.

It performs:

- beta reduction for function application
- simplification for `if`
- simplification for `succ`, `pred`, and `iszero` on numeric literals
- erasure of explicit annotations after checking

### 4. Type check

`cube-infer` infers types, and `cube-check` checks a term against an expected
type. Equality of types is definitional equality:

- normalize both sides
- compare them up to alpha-equivalence

This keeps the checker conceptually close to the usual presentations of small
dependent calculi.

## What The Core Can Demonstrate

### Terms depending on types

Polymorphic identity:

```scheme
'(lambda ((A Type)) (lambda ((x A)) x))
```

Its type is:

```scheme
'(Pi ((A Type)) (-> A A))
```

### Types depending on types

You can abstract over type constructors:

```scheme
'(lambda ((F (-> Type Type))) (F Bool))
```

This has type:

```scheme
'(-> (-> Type Type) Type)
```

### Types depending on terms

The language uses `Pi`, so dependent function types are part of the core.
With only the small built-in family of types in this project, interesting
term-indexed examples are limited, but the machinery is there:

```scheme
'(Pi ((x Nat)) Type)
```

That is one of the places where a future extension could add richer indexed
type families if you want more vivid dependent examples.

## API

Inside the Lisp interpreter, the main helpers are:

- `cube-type`
- `cube-check`
- `cube-normalize`
- `cube-eval`

The older helpers:

- `stlc-type`
- `stlc-check`
- `stlc-eval`

still work and now reuse the cube implementation.

## Example Proof Library

The file [proofs.scm](./proofs.scm) provides a small library of named proofs.

These are not built into the core language itself. They are ordinary host-Lisp
definitions whose bodies are quoted cube terms. That is deliberate: it keeps
the proof examples readable and easy to extend.

The library focuses on the connectives this tiny core can currently express
well:

- implication via function type
- universal quantification via `Pi`
- computational examples over `Bool` and `Nat`

Representative entries include:

- identity
- const
- compose
- flip
- apply
- twice
- bool-not
- double-not

After loading `proofs.scm`, the host interpreter gives you:

- `cube-proof-names`
- `cube-show-proof`
- `cube-proof-proposition`
- `cube-proof-term`
- `cube-check-all-proofs`

That makes the library useful both as reading material and as an executable
set of examples that can be re-checked at any time.

## Suggested Teaching Order

If you use this in class or for self-study, a friendly progression is:

1. Start with `Bool`, `Nat`, `lambda`, and `->`.
2. Show normalization on simple applications.
3. Introduce `Type` so types become first-class.
4. Replace `->` with `Pi` and explain dependency.
5. Show why normalization matters for type equality.

That sequence lets students see the system grow one idea at a time even though
the implementation lives in one unified core.
