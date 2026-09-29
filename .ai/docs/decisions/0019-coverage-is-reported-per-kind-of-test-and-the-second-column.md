# Coverage is reported per kind of test, and the second column is regions

The report was a per-module table measured by one `swift test` pass. It is now a row per **kind of
test** — unit, ui, snapshot, and everything merged — with no module breakdown at all. Davide's call:
the question worth asking of a module is which kind of test reaches it, and a per-module row cannot
answer that however many of them there are.

**A kind is a directory, because a directory is a bundle and a bundle is what a coverage profile can
be scoped to.** The package's `…Tests` directories are unit; `Apps/GranitaMobileSnapshotTests` is
snapshot; `Apps/GranitaMobileUiTests` will be ui. The iOS snapshot target was renamed from
`GranitaMobileTests` for exactly that reason — under the old name the obvious place to put a
behavioural test was the snapshot bundle, and the snapshot row would have started counting what a
different kind of test reached, silently and in the direction that looks like good news.

**Lines and regions, not lines and branches.** swiftc emits no branch coverage: llvm-cov reports
`branches: 0/0` across all 169,532 mapped lines in this project, Hummingbird and NIO and
swift-subprocess included, and there is no flag that changes it — the counter is clang's. `regions`
is the near-equivalent Swift does emit, one counter per `if`, `guard`, `case`, ternary and closure
body, and it moves when a path stops being taken even though the line total holds. Asked for and
approved as "Regions", labelled honestly rather than borrowing Oltre's "Branch" header for a number
that is not one.

**Two traps in measuring the simulator pass**, both of which produce an export with zero package
files and no error to explain it:

- `-enableCodeCoverage YES` instruments the **test bundle only**. The app and the local package
  targets it links keep no coverage mapping at all. `ENABLE_CODE_COVERAGE=YES` and
  `CLANG_COVERAGE_MAPPING=YES` as build settings are what reach every target in the graph.
- Under Xcode 26 an app's own code lives in `Granita.app/Granita.debug.dylib`; the launcher beside it
  carries no `__llvm_covmap`. Passing only the launcher to `llvm-cov` reads nothing.

**The `all` row is a profile-level union, not a sum of the rows.** `llvm-profdata merge` adds the
counters per function and one `llvm-cov export` over every object resolves them — the host binary
contributes the server modules the simulator never links, the simulator objects contribute the views
the host cannot render. Adding the rows would double-count every line two kinds both reach.

**The Coverage job now boots a simulator and runs the snapshot tests a second time**, duplicating
~15 minutes of a 10x-billed runner that the Snapshot job already spends. Bought deliberately: the
coverage pass wants the profile and ignores the verdict — it runs under `|| true` — so a stale
baseline reddens one job rather than two, which is the isolation the Snapshot job was split out for.

Rejected: attributing coverage to a kind by test-name suffix, Oltre-style. Oltre's Gradle filter
applies to every `Test` task at once; here the three kinds are already three separate bundles built
by two different toolchains, so a suffix would be a second, weaker convention layered over a
partition the build system enforces for free.

