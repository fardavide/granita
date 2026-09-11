# Why the layer edges are where they are

Evidence behind the rules in the `architecture` skill: the corrections that produced each edge, the
measurements that justified it, and the exceptions left in place deliberately.

The wider picture is in [`../../docs/architecture.md`](../../docs/architecture.md).

## Contents

- Why `Presentation` depends on `Ui`, and not the reverse
- Why no I/O in a view, and the excuse that got past it — including what the seam bought
- Why one model per unit, and the exception left in place
- Why each remaining edge is forbidden
- Why a composition root must stay wiring-only
- Why `Main` is a layer name rather than a list of today's roots
- Why exactly three speculative abstractions are permitted
- Why identifiers stay wrapped

## Why `Presentation` depends on `Ui`, and not the reverse

This is the direction **Davide corrected on 2026-08-19**, and it inverts what most SwiftUI projects
do.

- A **`Ui`** module is a vocabulary of **stateless views**. Each takes what it renders and reports
  what happened, through initialiser parameters and closures. It owns no view model, holds no state
  beyond a view's own, and knows nothing about where its data came from.
- A **`Presentation`** module owns the unit's `@Observable` model and **composes screens** out of
  those views. It is the outer of the two, so it is the one that changes when a screen changes.

That direction is what keeps a view reusable by more than the first screen that needed it: a view
that imported its model could only ever serve that one.

It also means a `Ui` module has no test target — there is nothing in one a test would want to
reach — while everything worth asserting sits in `Presentation`, one layer up.

## Why no I/O in a view, and the excuse that got past it

**A `body` is where a test cannot follow.** Anything a view calls on the world outside the process
is a line no unit test can execute and no baseline can drive, so it is invisible to both rows of the
coverage report at once — which is exactly how it goes unnoticed.

**The excuse to watch for is "it is one line with nothing to decide".** It was written into
`GranitaSettingsScreen` about a pasteboard call and was true; it stopped being true the day a folder
picker joined them, because **a picker decides** — it returns a folder or a reader who changed their
mind, and every call site branches on which. **By then the file was at 45 uncovered regions of 56.**

Davide, 2026-08-23: *Ui must be declarative; if a state cannot be driven by a model, and it isn't
testable because of that, we have a structural issue.*

### What the seam bought

- **Split a seam by whether it answers.** `FolderPicking` returns something and every caller
  branches; `SystemGestures` does not. One protocol for both would put a decision and a
  fire-and-forget behind one fake.
- **Questions became askable.** Whether Copy puts on the pasteboard the string the row shows;
  whether copying while the server is down copies the em dash it draws. Neither could be asked while
  the call was in a `body`, and both were worth asking.

## Why one model per unit

A state object per screen — `MenuBarViewModel` beside `ConnectionLogViewModel` — is a **vertical**
split wearing a layer's name: it cuts by which view draws the state rather than by what the state
is. Two views onto one running server then hold that server's state in two places.

`ServerMacModel` carries the server's state and the connection log; a new Settings tab adds
properties to it, not a type beside it.

### The exception left in place

The phone's `ServerDiscoveryViewModel` predates the rule and is left alone **deliberately**. Each
module converts as it is next opened rather than in a sweep; M4 converts the client's connection
feature when it reopens it.

See `decisions.md`, "One model per unit, not one per view".

## Why each remaining edge is forbidden

- **`Domain` sees no framework.** It defines the interfaces `Data` implements and knows nothing of a
  socket, a file or a screen. This is what lets the diff parser and every policy be tested as pure
  functions.
- **`Presentation` never imports `Data`.** A view model talks to a protocol its `Domain` owns. The
  day the implementation changes, only the composition root moves.
- **`Ui` never imports `Data` either**, which follows from having no reason to: it is handed values,
  it does not fetch them.

## Why a composition root must stay wiring-only

Nothing depends on the three roots, which is what makes the mixing safe rather than a hole: the
layers they cross cannot travel anywhere.

A root is exempt from both coverage rows — no host test constructs one and no baseline renders one —
so anything in a root that a test would want to assert is code that has quietly stopped being
visible as untested.

`Server/App` was carrying a server host with **four failure sentences nobody could reach**; moving
it out is what made them assertable.

## Why `Main` is a layer name rather than a list of today's roots

Naming the layer is what lets the coverage predicates ask which layer a file is in.

Two of the three roots used to be `Presentation` modules, and every place that mattered had to name
them one by one — the `architecture` skill, `architecture.md`, the manifest header, and a clause in
each of the two scope predicates saying that one particular `Presentation` module is not one.

The server's `Api/Presentation` is a presentation layer in the same sense as the client's —
domain-to-wire mapping plus routes. It has no `Ui` sibling because it has no views, and it is not a
composition root.

## Why exactly three speculative abstractions are permitted

Each buys a specific future that has already been asked for:

- **git access**, so a library-based backend could replace the process-based one without touching a
  call site, keeping a sandboxed Mac App Store build possible;
- **storage**, so the JSON document can be replaced if v2's comments grow the data;
- **the client's repository**, so the app can run against a bundled dataset with no Mac present.

Everywhere else a protocol earns its place by having a fake behind it today.

## Why identifiers stay wrapped

It stops a worktree identifier reaching a parameter expecting a file identifier, and it makes the
API's most important rule structural: **the API never accepts a filesystem path as an input.**

Addressing is by identifier, resolved against the server's registry of explicitly-enabled projects.
A path parameter would be a directory traversal hole in a service that streams private source code.

Mark-as-viewed state is keyed by **content hash**, never by path alone: a file marked viewed becomes
unviewed when the agent changes it again, and that behaviour is the feature.
