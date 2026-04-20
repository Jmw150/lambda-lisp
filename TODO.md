# TODO

This file tracks the most useful next steps for `coc-lisp`.

The project already has a good split between:

- a small host Lisp interpreter
- a separate typed core for Calculus-of-Constructions-style experiments

That split should guide future work. Features involving effects, operating
system interaction, or language extensibility should usually begin in the host
Lisp layer first.

## High Priority

### 1. Foreign Function Interface

Goal:

- allow host Lisp programs to call selected external functions

Why it fits this project:

- primitives already provide a clean capability boundary
- host-side interoperability is much more natural than pushing effects into the
  typed core

Questions to settle:

- should the first version use CHICKEN FFI directly, or a narrower wrapper API?
- should FFI support only a whitelist of bound functions, or user-declared
  signatures?
- how should strings, integers, booleans, and lists be marshaled?
- how much of this should work in the REPL versus only in compiled mode?

Known implementation constraint:

- CHICKEN's `foreign-lambda` works in compiled mode but not in interpreted mode,
  so test and build workflow may need to change if the FFI is added directly

Good first milestones:

- bind one simple function like `getpid`
- add a tiny host API such as `(ffi:getpid)`
- document compiled-mode limitations clearly
- add tests that run through the compiled binary

### 2. Scheme-Style Macros

Goal:

- add syntactic abstraction to the host Lisp

Why it matters:

- macros make the host language much more expressive
- they are a natural next step for a Lisp project headed toward GitHub
- they can reduce pressure to add many new special forms directly

Questions to settle:

- should the first system be simple `define-macro` style expansion or a more
  hygienic model?
- should macro expansion happen before evaluation only, or also during file
  loading?
- how much hygiene is required for the educational goals of the project?

Good first milestones:

- add `define-macro`
- expand macros at host-eval time before ordinary application
- support a few example macros like `when`, `unless`, and threaded `begin`
- document the difference between macros and functions

## Medium Priority

### 3. Better Host Lisp Coverage

Potential additions:

- `cond`
- `and` / `or`
- quasiquote / unquote
- rest parameters
- more list utilities
- string utilities
- better printing

### 4. Better Typed-Core Surface

Potential additions:

- richer base types
- more examples of dependent types indexed by terms
- explicit universe hierarchy instead of `Type : Type`
- additional eliminators or inductive-style encodings

### 5. Bridge Between Host Lisp And Typed Core

Potential additions:

- helpers for building cube terms more ergonomically
- pretty-printing of normalized terms and inferred types
- better proof-library tooling
- loading and organizing proof libraries by module

## Lower Priority But Valuable

### 6. Better Errors And Debugging

Potential additions:

- source-location-aware file loading
- clearer error messages for malformed cube syntax
- tracing hooks for macro expansion
- debug printers for environments and closures

### 7. Project Polish

Potential additions:

- package the project as a cleaner GitHub repository
- add more examples in an `examples/` directory
- split `lib.scm` into smaller modules if the code grows much further
- add CI-friendly test entry points

## Guiding Principle

Keep the architecture readable.

In particular:

- host-language effects should stay in the host evaluator
- the typed core should remain small unless a new feature materially improves
  its instructional value
- avoid mixing side-effectful foreign operations directly into normalization and
  type checking
