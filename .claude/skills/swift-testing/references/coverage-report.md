# What the coverage report measures, and why

Evidence behind the rules in the `swift-testing` skill's "Test kinds, and the coverage gate"
section. Read this when a row falls, when a scope looks wrong, or before proposing a redefinition.

## Contents

- Why one run per kind
- Why a row of dashes is not a zero
- Why the Snapshot row reads as "was this rendered"
- Why moving snapshot tests into the package would not fix a number
- What the Unit and All rows are measured over
- What the Snapshot row is measured over — including the 2026-08-23 measurement
- Why the Snapshot regions column leaves out action closures
- The redefinitions, and the one that was wrong
- Why a redefinition un-judges a row
- Why the denominators differ
- Why regions, not branches

## Why one run per kind

The `Coverage` job runs the suite **once per kind**, plus once with the profiles merged, because
coverage is a property of the tests that ran: the only way to say what the snapshot tests reach, as
opposed to what everything reaches, is to run them alone and read the profile.

The report is a row per kind and nothing else — there is no per-module breakdown, because the
question worth asking is which kind of test reaches the code, not which directory it sits in.

**The Snapshot kind is two bundles and one row.** There is no macOS simulator, so the two render in
different places, but the question the row answers is the same for both and a platform axis is not
one a reader of the report cares about. The two profiles are merged before the row is taken.

## Why a row of dashes is not a zero

`Ui` reads `—` because the target does not exist yet. The first behavioural test brings
`Apps/GranitaMobileUiTests` and its `project.yml` target with it, and the row starts carrying
numbers on the next `main` run.

## Why the Snapshot row reads as "was this rendered"

Rendering a screen executes every line that composes it, so `ClientConnectionUi` scores high the
moment any baseline puts it on screen. Line coverage cannot tell a rendered line from a driven one.
What the split is good for is the comparison *between* kinds on one module.

## Why moving snapshot tests into the package would not fix a number

A SwiftPM test target is hostless and renders blank, so the tests would still measure nothing —
they would just measure it inside the package. The split between the package suite and the
app-hosted suites is the reason the numbers mean anything.

## What the Unit and All rows are measured over

The package, minus view bodies **wherever they live**, minus the composition roots, minus the
handful of files named in `UNREACHABLE_FILES`.

Each exclusion has a construction reason:

- A SwiftUI body needs a renderer and a SwiftPM test target is hostless.
- No test constructs a composition root.
- A test binary is unsigned, so it has no keychain for the identity store to write to.

"Wherever they live" is load-bearing: `Presentation` holds both models and the screens composed from
`Ui`, and only the models are reachable — a file named `…Screen` is a body and is excluded, while
`ServerMacModel` is an ordinary object a test constructs and stays judged.

## What the Snapshot row is measured over

A `Ui` module plus the screens composed from one, and nothing else under a `Presentation`
directory. That layer holds three kinds of thing — models, screens, composition roots — and only the
middle one is code a picture executes.

Selecting the whole directory once had the row asking how much of a server host and a wiring module
a rendered screen ran. **Measured on 2026-08-23, that was 163 uncovered lines of a model, 18 of a
host and 9 of a composition root.** It is the mirror of the Unit row's rule, which excludes screens
for the opposite reason.

The row is measured over the view layers alone for a second reason: a rendered view executes no
repository and no parser, so every line of those the phone app happens to link is one a snapshot can
never cover. Measured over the whole package the row fell whenever domain code was added anywhere
under the app — a fact about the dependency graph, not about the snapshots. Scoped, it answers what
it is for: of the code that draws screens, how much does a baseline put on screen.

**The Ui kind is not scoped**, because a behavioural test drives the real app and reaching a
repository is exactly what it does.

## Why the Snapshot regions column leaves out action closures

A closure that returns `()` is an action — a `Button`'s, an `onChange`, a `.task`, an `onAppear`. It
draws nothing, and a baseline presses nothing, so it is outside the question this row asks rather
than merely untested by it. Same bar as `UNREACHABLE_FILES`: unrunnable by this kind of test *by
construction*, applied at the only granularity that can express it, because an action closure shares
a file — and usually a line — with the view it sits in.

**A named method returning `()` is not an action, and that is where the line is drawn.** A method has
a name, so a test can call it; a closure literal has neither a name nor a seam.

**Regions only, and that is measured rather than assumed.** Over the whole views scope on
2026-09-04, the exclusion took **200 of 1695 regions** out of the denominator and **7 of 5043
lines**. A closure written inline is spanned by the view expression containing it, so its lines are
the body's lines and removing them would remove the body. Lines stay counted and stay judged; only
the region number changed basis, 87.8% → 97.5%.

The predicate reads `xcrun swift-demangle --compact` and **parses** the result — it does not match
`-> ()` anywhere in the string. A demangled closure carries its enclosing context after ` in `, so
`closure #1 () -> SwiftUI.Text in …configure() -> ()` is a ViewBuilder inside a void method, and a
looser test would drop a view out of the denominator. The parameter list is scanned to its own
closing bracket for the same reason: a closure taking a closure puts an arrow inside its parameters.

**What it costs, and why that is acceptable.** View code is judged by this row and no other, so an
action closure's body is now judged by nothing. That is bounded by an architecture rule the project
already has: a screen's action closure is one call into a model, and the model is judged by the Unit
row. **A closure that grows a branch has outgrown a view** — move it to the model, where it is
judged, rather than arguing it back into this denominator.

## The redefinitions, and the one that was wrong

Every redefinition recorded in `decisions.md` so far was a correction, and one *proposal* was not —
it would have excluded models to fix a number while a screen was doing its own I/O.

The tell is whether the code the row cannot reach is code that *should not be there*: fix that
first, then ask whether the predicate is still wrong. Often it is, and the case for it is far
stronger once nothing else is.

This is why adding a name to `UNREACHABLE_FILES` counts as a redefinition and comes with a rename of
the scope string — that is what leaves the row unjudged for one run instead of failing the pull
request that makes the change.

## Why a redefinition un-judges a row

The summary records the files each kind's percentage was taken over, and the gate compares two
numbers only when both were taken the same way. A redefinition would otherwise fail the pull request
that makes it, for the redefinition rather than for a regression.

## Why the denominators differ

A pass only measures the code its own binaries map: the simulator never links the server modules,
and the host cannot render a view. Each row answers "of what this kind could reach, how much did
it", and only `All tests` spans the project.

The corollary is a hazard worth knowing: deleting the last test that pulls a module into a binary
removes that module's uncovered lines from the denominator, so the percentage goes *up*. **Coverage
rising after tests are deleted is the signature.**

## Why regions, not branches

swiftc emits no branch coverage — llvm-cov reports `branches: 0/0` for every Swift object,
dependencies included, and no flag changes it.

A region is an `if`, a `guard`, a `case`, a ternary or a closure body, and it moves when a path stops
being taken even though the line total holds.

## The `All tests` row is not comparable between this machine and the runner

`make coverage` gives the runner's verdict on five of the six values and **not on `All tests`
lines**, and that is measured rather than suspected. On 25 August 2026, on a clean tree at `1a7acef`
with nothing changed, the local run read 12 covered lines below the number `main`'s own run published
for that same commit. The other five values matched to the line.

The per-file exports say where, which is why they exist:

| Δ (runner − here) | File |
|---|---|
| **+17** | `Server/Api/Presentation/ApiServer.swift` |
| −4 | `Client/Connection/Data/BonjourBrowser.swift` |
| −1 | `Server/Sessions/Data/SessionIndex.swift` |

All three are code that **runs because a snapshot suite is app-hosted**, not code any test drives.
`TEST_HOST` launches the real app, so the Mac's suite starts the real server and the phone's starts a
real browser, and how far each gets before the first baseline is rendered depends on the machine: a
laptop that already has Granita's port taken, a browser the simulator answers differently, a run
where the Mac's suite is red from the first assertion. Merging those profiles is what `all` is, so
`all` inherits the variance and the two single-kind rows do not.

**So read a fallen `All tests` lines row here as a question rather than an answer**, and settle it by
comparing the *uncovered line count* against a clean-tree run of the same working copy — that number
is stable across the difference, and it is the one the report prints beside the table. The five other
values are the verdict, unchanged.

Downloading the runner's own per-file export is one command and is what settled this:

```bash
gh run download <run-id> --repo fardavide/granita -n coverage-exports -D <dir>
```

It is ~300 MB, which is why `Scripts/fetch-coverage-baseline.sh` takes the six numbers instead — but
when a row falls and the arithmetic does not explain it, this is the thing that does.
