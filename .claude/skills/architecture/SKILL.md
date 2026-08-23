---
name: architecture
description: Granita's module rules — the <Unit>/<Feature>/<Layer> tree, which layer may import which, the three composition roots, adding a module, typed opaque identifiers, and dependency inversion with handwritten fakes.
when_to_use: >
  Consult before creating a module or a directory that will hold one, before adding any dependency
  line to Package.swift, before deciding where a new type belongs, and whenever a build fails with
  a missing module that "should" be visible. Also when adding an external dependency, or when the
  user asks where something should live.
---

# Architecture

The rules below are enforced by the target dependency graph in
`Packages/Granita/Package.swift`. A module cannot reach what it does not declare, so a violation is
a compile error rather than a review comment. When one of these feels obstructive, that is the rule
working — move the logic, do not add the edge.

Rationale and the wider picture are in [`../../docs/architecture.md`](../../docs/architecture.md).

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

**`Presentation` depends on `Ui`, not the other way round.** This is the direction Davide corrected
on 2026-08-19, and it inverts what most SwiftUI projects do, so it is worth stating plainly:

- A **`Ui`** module is a vocabulary of **stateless views**. Each takes what it renders and reports
  what happened, through initialiser parameters and closures. It owns no view model, holds no state
  beyond a view's own, and knows nothing about where its data came from.
- A **`Presentation`** module owns the unit's `@Observable` model and **composes screens** out of
  those views. It is the outer of the two, so it is the one that changes when a screen changes.

## No I/O in a view or a screen — not even one line of it

**A `body` is where a test cannot follow.** Anything a view calls on the world outside the process
is a line no unit test can execute and no baseline can drive, so it is invisible to both rows of the
coverage report at once — which is exactly how it goes unnoticed.

The rule is the same one every other edge already follows, applied where it is most often waived: a
`Ui` view reports what happened and a screen calls a **model**, and the model calls a protocol its
`Domain` owns. No `NSOpenPanel`, no `NSPasteboard`, no `NSWorkspace`, no `FileManager`, no
`URLSession`, no `UserDefaults` in a view or a screen.

**The excuse to watch for is "it is one line with nothing to decide".** It was written into
`GranitaSettingsScreen` about a pasteboard call and was true; it stopped being true the day a folder
picker joined them, because **a picker decides** — it returns a folder or a reader who changed their
mind, and every call site branches on which. By then the file was at 45 uncovered regions of 56.
Davide, 2026-08-23: *Ui must be declarative; if a state cannot be driven by a model, and it isn't
testable because of that, we have a structural issue.*

Two things follow, and they are what the seam buys rather than what it costs:

- **Split a seam by whether it answers.** `FolderPicking` returns something and every caller
  branches; `SystemGestures` does not. One protocol for both would put a decision and a fire-and-
  forget behind one fake.
- **Questions become askable.** Whether Copy puts on the pasteboard the string the row shows;
  whether copying while the server is down copies the em dash it draws. Neither could be asked while
  the call was in a `body`, and both were worth asking.

If a gesture genuinely has nothing to decide and nothing to assert, it still goes behind the seam —
a rule applied by size rather than by kind is not one.

## One model per unit, never one per view

A state object per screen — `MenuBarViewModel` beside `ConnectionLogViewModel` — is a **vertical**
split wearing a layer's name: it cuts by which view draws the state rather than by what the state
is. Two views onto one running server then hold that server's state in two places.

- A unit's `Presentation` holds **one** `@Observable` model, named for the unit and not for a
  screen. `ServerMacModel` carries the server's state and the connection log; a new Settings tab
  adds properties to it, not a type beside it.
- Do not name anything `…ViewModel` in new code. The name is the reflex being removed.
- If one model stops being readable, split it by **what it wraps** — a layer concern — never by
  which screen draws it.
- Views are unchanged by this: they stay stateless and are handed values.

The phone's `ServerDiscoveryViewModel` predates the rule and is left alone deliberately. Each
module converts as it is next opened rather than in a sweep; M4 converts the client's connection
feature when it reopens it. See `decisions.md`, "One model per unit, not one per view".

That direction is what keeps a view reusable by more than the first screen that needed it: a view
that imported its model could only ever serve that one. It also means a `Ui` module has no test
target — there is nothing in one a test would want to reach — while everything worth asserting sits
in `Presentation`, one layer up.

The other edges are each forbidden for their own reason:

- **`Domain` sees no framework.** It defines the interfaces `Data` implements and knows nothing of a
  socket, a file or a screen. This is what lets the diff parser and every policy be tested as pure
  functions.
- **`Presentation` never imports `Data`.** A view model talks to a protocol its `Domain` owns. The
  day the implementation changes, only the composition root moves.
- **`Ui` never imports `Data` either**, which follows from having no reason to: it is handed values,
  it does not fetch them.

## The three composition roots are the `Main` layer

`ClientAppMain`, `ServerAppMain` and the `granita-server` executable at `Server/Cli/Main` are the
**only** modules that import a `Data` target, because wiring implementations into protocols is their
entire job. Nothing depends on them, which is what makes the mixing safe rather than a hole: the
layers they cross cannot travel anywhere. Each Xcode shell links exactly one of these products.

**A root holds wiring and nothing else.** It is exempt from both coverage rows — no host test
constructs one and no baseline renders one — so anything in a root that a test would want to assert
is code that has quietly stopped being visible as untested. When you find logic in one, the fix is to
move it to a judged module and give it a seam, not to leave it and note the exemption. `Server/App`
was carrying a server host with four failure sentences nobody could reach; moving it out is what made
them assertable.

**`Main` is a layer name rather than a list of today's roots**, which is what lets the coverage
predicates ask which layer a file is in. Two of the three used to be `Presentation` modules, and
every place that mattered had to name them one by one — this skill, `architecture.md`, the manifest
header, and a clause in each of the two scope predicates saying that one particular `Presentation`
module is not one.

The server's `Api/Presentation` is a presentation layer in the same sense as the client's —
domain-to-wire mapping plus routes. It has no `Ui` sibling because it has no views, and it is not a
composition root.

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

Three protocols also carry a forward-looking job, and they are the **only** speculative abstractions
the project permits:

- git access, so a library-based backend could replace the process-based one without touching a call
  site, keeping a sandboxed Mac App Store build possible;
- storage, so the JSON document can be replaced if v2's comments grow the data;
- the client's repository, so the app can run against a bundled dataset with no Mac present.

Everywhere else a protocol earns its place by having a fake behind it today. Do not add one for a
future that has not been asked for.

## Identifiers are opaque, typed, and never unwrapped for convenience

Projects, worktrees and files are addressed by hashes of their canonical paths. Each has its own
wrapper type, propagated through **every** signature, return type, field, lambda parameter and local
— unwrap to the underlying string only at the call site of an API that demands one.

This is not decoration. It is what stops a worktree identifier reaching a parameter expecting a file
identifier, and it is what makes the API's most important rule structural: **the API never accepts a
filesystem path as an input.** Addressing is by identifier, resolved against the server's registry of
explicitly-enabled projects. A path parameter would be a directory traversal hole in a service that
streams private source code.

Mark-as-viewed state is keyed by **content hash**, never by path alone: a file marked viewed becomes
unviewed when the agent changes it again, and that behaviour is the feature.

## Platform split

`Core/*` compiles for iOS and macOS. `Client/*` is exercised on iOS and iPadOS. `Server/*` is
macOS-only and free to use macOS-only APIs, and stays out of the phone because the phone's shell
links only the client's composition root. CI builds both slices, which is what keeps the split
honest.
