---
name: architecture
description: Granita's module rules — the <Unit>/<Feature>/<Layer> tree, which layer may import which, no I/O in a view, one model per unit, the three composition roots, adding a module, typed opaque identifiers, and dependency inversion with handwritten fakes.
when_to_use: >
  Consult before creating a module or a directory that will hold one, before adding any dependency
  line to Package.swift, before deciding where a new type belongs, and whenever a build fails with
  a missing module that "should" be visible. Also when adding an external dependency, when putting
  any call to the outside world near a view, or when the user asks where something should live.
---

# Architecture

The rules below are enforced by the target dependency graph in
`Packages/Granita/Package.swift`. A module cannot reach what it does not declare, so a violation is
a compile error rather than a review comment. When one of these feels obstructive, that is the rule
working — move the logic, do not add the edge.

Rationale and the wider picture are in [`../../docs/architecture.md`](../../docs/architecture.md).
The corrections, measurements and deliberate exceptions behind each edge below are in
[layer-rationale.md](references/layer-rationale.md) — read it before overriding one of these.

## Layout — a feature is a directory of modules, never one module

```
Packages/Granita/<Unit>/<Feature>/<Layer>
```

`Unit` is `Core`, `Client` or `Server`. `Layer` is `Domain`, `Data`, `Presentation`, `Ui` or `Main`.
A module's name is its path with the slashes removed, so `Client/Viewer/Data` is
`import ClientViewerData` and the tree on disk matches the import list at the top of every file.

Create only the layers a feature actually needs — there are no empty placeholder layers. A test
target is a sibling named for what it tests: `Client/Viewer/DomainTests` is
`ClientViewerDomainTests`.

Every target declares an explicit `path:`. There is no `Sources/` wrapper, and adding one would
break the name-equals-path property that makes the tree readable.

## The four layer rules

| Layer | May depend on | Never |
|---|---|---|
| `Domain` | other `Domain` targets, Foundation | any framework, any I/O |
| `Data` | `Domain` targets, plus at most **one** external infra dependency | another feature's `Data` |
| `Ui` | `Domain` for the model types it renders, SwiftUI | any `Presentation`, any `Data` |
| `Presentation` | its feature's `Ui`, `Domain` targets | any `Data` target |
| `Main` | anything — a composition root mixes layers on purpose | being depended on by anything |

**`Presentation` depends on `Ui`, not the other way round.** A `Ui` module is a vocabulary of
stateless views, each taking what it renders and reporting what happened. A `Presentation` module
owns the unit's `@Observable` model and composes screens out of those views — it is the outer of the
two.

## No I/O in a view or a screen — not even one line of it

This is the same rule every other edge already follows, applied where it is **most often waived**: a
`Ui` view reports what happened, a screen calls a **model**, and the model calls a protocol its
`Domain` owns. No `NSOpenPanel`, no `NSPasteboard`, no `NSWorkspace`, no `FileManager`, no
`URLSession`, no `UserDefaults` in a view or a screen.

- **"It is one line with nothing to decide" is the excuse to watch for.** It is how the rule gets
  waived, and it stops being true the moment a control that *decides* joins the ones that did not.
- **Split a seam by whether it answers.** A protocol whose calls return something every caller
  branches on does not share a fake with a fire-and-forget one.
- **A gesture with nothing to decide and nothing to assert still goes behind the seam** — a rule
  applied by size rather than by kind is not one.

## One model per unit, never one per view

- A unit's `Presentation` holds **one** `@Observable` model, named for the unit and not for a
  screen.
- Do not name anything `…ViewModel` in new code. The name is the reflex being removed.
- If one model stops being readable, split it by **what it wraps** — a layer concern — never by
  which screen draws it.
- Views are unchanged by this: they stay stateless and are handed values.
- **Convert on next open, never in a sweep.** One pre-rule model is left in place deliberately; see
  the reference before "fixing" it.

## The three composition roots are the `Main` layer

`ClientAppMain`, `ServerAppMain` and the `granita-server` executable at `Server/Cli/Main` are the
**only** modules that import a `Data` target, because wiring implementations into protocols is their
entire job. Each Xcode shell links exactly one of these products.

**A root holds wiring and nothing else.** It is exempt from both coverage rows, so anything in a
root that a test would want to assert is code that has quietly stopped being visible as untested.
When you find logic in one, move it to a judged module and give it a seam — do not leave it and note
the exemption.

**`Main` is a layer name rather than a list of today's roots**, which is what lets the coverage
predicates ask which layer a file is in.

## Adding a module

1. Put it at `<Unit>/<Feature>/<Layer>`, creating the feature directory if it is new.
2. Add the target to `Package.swift` with an explicit `path:` and the Swift 6 language-mode setting;
   add the main-actor default isolation setting too if it is a `Ui` or `Presentation` target.
3. Declare only the dependencies the table above permits. If the one you want is forbidden, the
   design is wrong, not the rule.
4. Name it for its layer only if it **is** that layer. A module that legitimately spans layers is a
   composition root and must be able to say why.

## Adding an external dependency — ask first

There are exactly three, each pinned to exactly one module: the HTTP server in the API presentation
module, the syntax highlighter in the viewer's `Ui`, the subprocess library in the git `Data`
module. **No other module may declare an external product**, and a fourth dependency is a
conversation with Davide before it is a commit.

## Dependency inversion at every I/O edge

Anything touching the outside world sits behind a protocol its `Domain` owns, with one
implementation in a `Data` module. Constructor injection everywhere; no service locator, no
singletons. Tests build the subject directly with handwritten fakes — see the `swift-testing` skill.

**Exactly three protocols are permitted to be speculative** — git access, storage, and the client's
repository. Everywhere else a protocol earns its place by having a fake behind it today. Do not add
one for a future that has not been asked for. What each of the three buys:
[layer-rationale.md](references/layer-rationale.md).

## Identifiers are opaque, typed, and never unwrapped for convenience

Projects, worktrees and files are addressed by hashes of their canonical paths. Each has its own
wrapper type, propagated through **every** signature, return type, field, lambda parameter and local
— unwrap to the underlying string only at the call site of an API that demands one.

This is not decoration. It is what makes the API's most important rule structural: **the API never
accepts a filesystem path as an input.** Addressing is by identifier, resolved against the server's
registry of explicitly-enabled projects.

Mark-as-viewed state is keyed by **content hash**, never by path alone.

## Platform split

`Core/*` compiles for iOS and macOS. `Client/*` is exercised on iOS and iPadOS. `Server/*` is
macOS-only and free to use macOS-only APIs, and stays out of the phone because the phone's shell
links only the client's composition root. CI builds both slices, which is what keeps the split
honest.
