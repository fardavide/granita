# Architecture

How Granita is organised, and why the shape holds itself together. Read this and
[`decisions.md`](decisions.md) before any non-trivial change.

Concepts and contracts here, not type names — names rot on rename.

## The two halves and the wire between them

A Mac holds the source and the `git` binary. A phone holds the reader. Between them is a JSON API
over TLS on the local network, and the client is a strict consumer of it: it never sees a filesystem
path it could ask about, only opaque identifiers the server resolves against its own registry of
explicitly-enabled projects. That rule is the security boundary, not a stylistic one — the payload
is private source code, and a path parameter would be a traversal hole.

The Mac app embeds the backend in-process. The same backend is also an executable, so the whole
server side builds, runs and is tested from a terminal with no Xcode in the loop. The menu bar app is
a delivery mechanism for it, not its host.

## One package, four layers, module boundaries as the enforcement

Everything testable lives in a single local Swift package. The two Xcode targets are thin `@main`
shells that link exactly one product each, so nothing worth testing is trapped in an app bundle and
the whole logic suite runs on the host with no simulator.

Inside the package, a feature is a **directory** containing one module per layer:

```
<Unit>/<Feature>/<Layer>
```

A module's name is its path with the slashes removed, so the tree on disk and the import list at the
top of a file say the same thing. `Unit` is `Core`, `Client` or `Server`; `Core` compiles for both
platforms, `Client` is exercised on iOS and iPadOS, `Server` is macOS-only and free to use
macOS-only APIs.

The layer rules are declared once, in the package manifest, and enforced by the compiler:

| Layer | May depend on | Never |
|---|---|---|
| `Domain` | other `Domain` targets, Foundation | frameworks, I/O |
| `Data` | `Domain` targets, plus at most **one** external infra dependency | another `Data`'s internals |
| `Ui` | `Domain` for the model types it renders, SwiftUI | any `Presentation`, any `Data` |
| `Presentation` | its feature's `Ui`, `Domain` targets | any `Data` target |
| `Main` | anything — it is a composition root | being depended on by anything |

**`Presentation` depends on `Ui`**, which inverts what most SwiftUI projects do and is deliberate. A
`Ui` module is a vocabulary of stateless views: each takes what it renders and reports what happened,
owning no view model and no state beyond a view's own. A `Presentation` module owns the view models
and composes screens out of those views, so it is the outer of the two and the one that changes when
a screen changes.

The payoff is reuse in the direction that matters. A view that imported its view model could only
ever serve the one screen that view model belonged to; a view that takes values and closures serves
any screen that has them. It also puts everything worth asserting one layer up: a `Ui` module has no
test target because there is nothing in one a test would want to reach.

This is the whole boundary system. A domain module cannot reach a network client because it does not
declare it, so a violation is a compile error rather than a review comment. When a rule feels
obstructive, that is the rule working: the fix is to move the logic, not to add the edge.

The three composition roots — the phone's, the menu bar app's, and the executable's — may mix
layers, because wiring implementations into protocols is their entire job. They are the only modules
that import a `Data` target, and nothing depends on **them**, which is what makes that safe rather
than a hole.

**They are a layer, `Main`, rather than an exemption written down in prose.** Two of the three used
to be filed under `Presentation` and were exempted by name wherever the distinction mattered: in this
document, in the manifest's header, and twice in the coverage report's scope predicates, which each
had to carry a clause saying that one particular `Presentation` module is not one. A rule spelled in
four places is a rule that drifts, and the coverage clauses were the same fact written twice in
different words. Naming the layer replaces all four with a directory name, matched exactly the way
`Ui` is — and one of the two clauses disappears outright, because `Main` is neither `Ui` nor
`Presentation` and so nothing in a root selects into the drawing scope in the first place.

What a root may hold is **only wiring**. Anything in one that a test would want to assert is in the
wrong module, because a root is exempt from both coverage rows and an exempt module is where
untested code stops being visible as untested. The menu bar root was carrying a server host whose
four failure sentences no test could reach; they are asserted now, from a module that is judged.

The server's API module is a `Presentation` layer in the same sense as the client's: domain-to-wire
mapping plus routes. It has no `Ui` sibling because it has no views.

## Dependency inversion at every I/O edge

Anything that touches the outside world sits behind a protocol owned by a `Domain` module, with one
implementation in a `Data` module and a hand-written fake in tests. There is no mocking framework and
no service locator: types are built with constructor injection, so a test constructs the subject
directly with the doubles it wants.

Three of these protocols carry a second job. Git access goes through one so a libgit2 backend could
replace the process-based one without touching a call site, which is what keeps a sandboxed Mac App
Store build possible later. Storage goes through one so the JSON document can be replaced if v2's
comments make the data grow. The client's repository goes through one so the app can run against a
bundled dataset with no Mac present, without the views knowing.

Those three are the **only** speculative abstractions the project permits. Everywhere else, a
protocol earns its place by having a fake behind it today.

## Exactly three external dependencies

One HTTP server, one syntax highlighter, one subprocess library — each pinned to exactly one module,
declared in one manifest. No other module may declare an external product, and a fourth dependency is
a conversation with Davide rather than a commit.

The subprocess library is not a convenience. Running `git` with the standard process API deadlocks
whenever the child outwrites the pipe buffer unless both streams are drained concurrently, which
large diffs do routinely, and it hands the child the app's own process group, which makes killing it
on a timeout dangerous.

## Identifiers are opaque and typed

Projects, worktrees and files are addressed by hashes of their canonical paths, never by the paths
themselves. Each has its own wrapper type, propagated through every signature, return type and
lambda parameter — a raw string only appears where a legacy API demands one. This is what stops a
worktree identifier reaching a parameter expecting a file identifier, and it is what makes the API's
"no paths as input" rule structural rather than remembered.

The mark-as-viewed state is keyed by a **content hash**, not by path: a file marked viewed becomes
unviewed automatically when the agent changes it again. That behaviour is the feature, not an
implementation detail of it.

## Generated files that are committed

Three artefacts are generated and committed, each for a reason that only surfaces at release time:
the Xcode project, the golden diff fixtures, and the app icon sets. A CI job regenerates all three
and fails if anything moved, and the same job re-runs the fixture generator from a differently-named
directory so nothing can smuggle the build location into a committed file. See the `generated-files`
skill before editing any of them.
