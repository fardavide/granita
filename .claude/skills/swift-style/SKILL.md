---
name: swift-style
description: Granita's Swift 6 and SwiftUI conventions — strict concurrency and actor isolation, optionality discipline, exhaustive switch, typed throws with domain error enums, naming without consecutive uppercase, import grouping, member ordering, no init defaults on domain models, and SwiftUI styling.
when_to_use: >
  Consult when writing or reviewing Swift production code — adding a type, a view model or a
  SwiftUI view, choosing optionality or error handling, or naming something. Also when building a
  screen to a design, or when the user flags Swift style.
---

# Swift style

The global `typing` and `refactor` skills apply too; this one owns what is Swift-specific and what
differs from a default Swift project.

## Concurrency — Swift 6, complete checking

Every target compiles in Swift 6 language mode, so strict concurrency checking is `complete`.
`Presentation` and `Ui` targets are **main-actor by default** through a package setting; `Domain`,
`Data` and everything on the server is not.

- Do not pepper `Presentation` and `Ui` code with `@MainActor` — it is the default there. Annotate
  only the few things that must run **off** the main actor.
- Server and `Domain` code is non-isolated by default. Say what it needs explicitly, and reach for an
  actor where shared mutable state genuinely exists — the store and the session index are actors for
  that reason.
- Types crossing an isolation boundary must be `Sendable`. Make value types `Sendable` rather than
  reaching for `@unchecked`; **`@unchecked Sendable` requires a written justification on the line**
  explaining what upholds the invariant the compiler cannot see.
- No queue hopping for concurrency. `async`/`await` and structured tasks.

## Optionality — do not invent nullability

Do not make a type optional because "the caller might not have one". An optional defers the decision
and forces every consumer downstream to handle a `nil` that may represent an impossible state. If you
reach for `T?` in new design, **stop and ask**: say what `nil` would mean and what the alternatives
are — an enum case, a required parameter, a separate type. Inheriting optionality from a system API
is fine; inventing it is not.

No force-unwraps without a written justification on the line. `try!` and `as!` are banned in
production code.

## Exhaustive `switch` — no catch-all `default`

A `switch` over an enum enumerates every case. A `default:` defeats the compiler's exhaustiveness
check, which is the only thing that will tell you a new case needs handling — and this project's
enums (file status, diff line kind, error codes) are exactly the ones that grow.

## Errors — typed, domain-owned, never swallowed

Repository and service boundaries use **typed throws**, so the error type is part of the signature.
The error is a domain enum owned by the feature, carrying domain-level reasons — never transport or
git vocabulary. The `Data` layer maps process failures, exit codes and decoding failures into it.

- No empty `catch {}`. No `try?` to silence a warning.
- **A failed git invocation surfaces with its stderr.** It is the only thing that makes a failure
  diagnosable from a phone, and the API has an error code that carries it.
- The API's error codes are part of the wire contract because the client branches on them. Adding one
  is a contract change, not an implementation detail.

## Typed wrappers, not primitives

Domain identifiers get wrapper types and keep them through every signature. Never strip one to a
`String` for convenience — see the `architecture` skill for why this one is load-bearing rather than
stylistic.

## Naming — no consecutive uppercase

Identifiers we define use single-capital segments: `Dto` not `DTO`, `Url` not `URL`, `Http` not
`HTTP`, `Api` not `API`, `Json` not `JSON`, `Id` not `ID`, `Spki` not `SPKI`. Apple's own types keep
their spelling — write `URL`, `URLSession`, `HTTPURLResponse`, `JSONDecoder` as they are.

No abbreviations. Names are documentation; a function describes behaviour, not implementation.

## Imports — grouped and alphabetical

Three groups, one blank line between, each sorted:

1. System frameworks (`Foundation`, `SwiftUI`, `Observation`, `Testing`)
2. Third-party
3. Project modules, with `@testable import` lines last

Insert in sorted position; never append at the end of a group.

## Member ordering

Within a type body:

1. Public stored properties
2. Private stored properties — hoisted only when initialisation order forces it
3. `init`
4. Public methods
5. Private methods
6. Nested types

A view model's `State` enum leads the type, because it is the vocabulary the properties below are
typed with. Free helpers and file-private types go at the **bottom of the file**, outside the type.
New members go into their group in place, never appended at the end.

## Initialisers — no defaults on domain models

Stored properties in a domain `struct` get no default values in the memberwise init: callers must
pass every value so the compiler catches a missing one, and so a newly-added field breaks every call
site until it is handled rather than silently absorbing a wrong value. Defaults belong in factory
functions and test factories.

## Values and immutability

Prefer `struct` and `enum` over `class`; prefer `let` over `var`. Make invalid states
unrepresentable with enums rather than boolean and optional soup.

Never create a stream just to read its current value synchronously — if you need a one-shot value,
use the suspending accessor. Reactive streams are for reacting to change over time.

## Abstraction granularity

Do not add a tiny helper — function, computed property, extension — that only renames or slightly
shortens an inline expression. Every new name is a memory tax on the reader, who has to learn it
before they can read anything else. Inline it unless the helper encapsulates non-trivial logic, is
reused three or more times with a clear meaning, or its name makes intent substantially clearer than
the expression.

## SwiftUI

- **Semantic colours only**, no hardcoded hex. Light and dark are both first-class, and there is a
  colourblind-safe palette toggle, so a hardcoded colour is three bugs rather than one.
- `@Observable` view models, injected through the view's init. No `ObservableObject` or `@Published`
  in new code.
- Keep views small. Push logic into the view model — a `Ui` module should contain nothing a test
  would want to reach.
- **Theme the system control rather than hand-rolling one.** When a design shows a control, find the
  system control with that behaviour and style it until it reads like the design. Reproducing a mock's
  pixels by hand is more code and worse: no dark mode, no Dynamic Type, no platform drift. Build a
  custom component only when no system control has the behaviour, and say why.
- The diff viewer has its own hard constraints — append-only loading, sticky measured heights,
  character wrapping, never reflowing above the viewport. Those are in `SPEC.md` §10 and are not
  style preferences; read them before touching the scroll.

## Documentation

Do not add comments that restate the code. A comment earns its place by explaining a non-obvious
*why*, a gotcha, or a constraint the code cannot express — of which this project has many, because
most of the git layer exists to work around behaviour that is not obvious from the command being
run. When in doubt, leave it out.
