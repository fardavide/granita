# Decisions

Key choices and why (ADR-style, newest last). Several were settled with Davide during setup —
**check here before re-litigating.**

`SPEC.md` is the specification. This file is the record of what was decided on top of it, and of
every place the repository deliberately departs from it.

## Swift, native on both ends, iOS 26 / macOS 26 minimum

Locked by Davide in the brief. The client is a native iOS and iPadOS SwiftUI app, universal, with a
real split view on iPad from v1; the server is Swift too, so one language and one test framework
cover the whole product. A minimum of iOS 26 / macOS 26 buys modern Observation, `@Observable`,
Swift 6.2 language features and current SwiftUI scroll APIs with no back-deployment shims — the
audience is one person's own phone, so there is no installed base to carry.

## Uncommitted working state only, no committed history

Locked. Everything between `HEAD` and the working tree — staged, unstaged, and untracked files
rendered as fully added ones. Ignored files are never shown. This is the state an agent leaves
behind, and it is what there is to review; committed history is a different product and browsing it
is explicitly v2. Keeping the scope this narrow is what makes a single comparison the source of
truth for both the file list and its stats, which in turn avoids the whole class of bug in SPEC §5.3.

## Public repository

Chosen over private. Both reference projects — `fardavide/oltre` and `fardavide/Aura` — are public
with an active `protect-main` ruleset, and on the GitHub Free plan a ruleset only enforces on public
repositories. Private would have meant `main` unprotected: no required checks, direct pushes
possible. What is private here is the source code Granita *serves*, not Granita itself.

## Xcode Cloud for delivery, over GitHub Actions plus a release script

SPEC §12 and §15 describe `Scripts/release.sh` uploading with an App Store Connect API key. Davide
chose Xcode Cloud instead, which is what Aura and Oltre already use. Xcode Cloud manages code
signing itself: no distribution certificate, no provisioning profile, no `.p8` key in GitHub secrets,
and no yearly certificate-expiry chore. The alternative needs at least one long-lived Apple
credential materialised onto a runner, and there is no zero-secret variant of it.

Two costs, stated so they are not discovered later. The workflow is **server-side state** living on
the App Store Connect app record — it cannot be code-reviewed, diffed, or restored from git, so a
repository with no CI config for its most consequential pipeline is expected rather than missing.
And the membership includes 25 compute hours a month; beyond that it is paid.

The two apps ship differently, because they must. `GranitaMobile` goes to TestFlight. `GranitaMac`
cannot: TestFlight distribution for macOS requires an App Store-signed build, and the Mac app is
deliberately unsandboxed. It archives with Developer ID and is notarised instead.

## The generated Xcode project is committed, not gitignored

The one deliberate departure from SPEC §2, which calls `Granita.xcodeproj` "a generated, gitignored
build artifact". Xcode Cloud requires a project that is "continuously present" in the repository and
reads its product list from **shared schemes**; generating the project at build time is explicitly
unsupported by Apple, and a scheme that is not committed does not exist as far as Xcode Cloud is
concerned. Oltre already resolved this the same way for `iosApp/`.

What the spec was protecting is untouched: `project.yml` remains the only source, `make project` is
the only way the project moves, and `project.pbxproj` is never hand-edited. A CI job regenerates it
and fails if anything drifted, so the committed copy cannot silently diverge from its source.

This also retires the spec's `Package.resolved` trap. That trap existed because gitignoring the
project also gitignored the resolved file inside it; with nothing under the project ignored, the
pins are committed either way.

## `CoreBrandingDomain`, a module the spec's tree does not list

SPEC §1 asks for the product name, bundle identifier prefix, Bonjour service type, URL scheme and
Application Support directory to live in "a single `Branding.swift`" so a rename is a two-file
change. Both units need those values, so a Core module is the only place that satisfies "single"
without a copy on each side. The alternative — putting them in `CoreDiffDomain` — would have made
the diff domain the home of unrelated constants.

## The agent harness lives under one `.claude/` root

Oltre's shape, chosen over Aura's `.ai/docs` plus `.claude/` split. One root means nothing to keep
in sync and one place to look. The split is the right answer when a repository must serve several
agent tools; Granita is Claude-only until it is not, and switching later is a contained migration —
move the tree, add symlinks, record it here.

## Golden diff fixtures are generated and committed before the parser that reads them

The unified diff parser is the highest-risk component in the product, and SPEC §6 says to build it
first, test first, against golden fixtures. Generating the corpus in the scaffold rather than
alongside the parser means the parser is written against something real from its first failing test,
and it means the §6 case list is demonstrably covered before anyone claims it is.

`Scripts/make-fixture-repo.sh` drives the real `git` binary over every case and **asserts the traps
the design depends on** rather than merely producing output — the two `-z` rename layouts with
opposite path orders, `diff --no-index` exiting 1 on success, unborn HEAD, and a conflicted path
emitting a normal unified diff rather than `diff --cc`. Verified against git 2.52.0 locally and
2.55.0 on the runner. A future git release that changes one of those turns CI red with a readable
diff instead of leaving a parser quietly reading the wrong field.

Committing the resulting `.diff` files as well as the generator is what lets the parser suite run on
a machine with no git at all.

## Fixtures must be independent of where they are built, and that is checked

Two separate leaks put the build location into a committed fixture and cost two red CI runs:
`.gitmodules` recorded an absolute submodule url, which changed the superproject's tree and therefore
every commit hash recorded in the worktree listing; and git reports worktree paths with symlinks
resolved, so on macOS an output directory under `/var` came back as `/private/var` and escaped the
path rewrite.

`make verify-generated` now regenerates a second time from a differently-named directory and diffs
the result. Two runs in the same directory cannot catch this class of bug, which is exactly why it
reached CI twice — and the new check is what found the symlink case, rather than a third red run.

The worktree listing is the only golden file that is edited on the way out: its root is rewritten to
a fixed token, because absolute paths are inherent to that command's output. The record layout, which
is the thing being asserted, stays byte-for-byte as git emitted it.

## `Presentation` depends on `Ui`, not the other way round

Davide's correction, 2026-08-19, overriding an earlier draft of SPEC §3 that had the usual SwiftUI
arrangement — views importing their view models, `Presentation` never importing SwiftUI. Both the
spec and the module graph were changed to match, and the two app composition roots moved from `Ui`
into `Presentation` with them.

`Ui` is now the **inner** of the two view layers: a vocabulary of stateless views, each taking what
it renders and reporting what happened through initialiser parameters and closures, owning no view
model. `Presentation` owns the `@Observable` view models and composes screens out of those views.

What this buys is reuse in the direction that matters. A view that imports its view model can only
ever serve the one screen that view model belongs to; a view that takes values and closures serves
any screen that has them. It also puts everything worth asserting one layer up — a `Ui` module has
no test target, because there is nothing in one a test would want to reach.

The cost, stated because the earlier draft treated the opposite as a feature: `Presentation` now
sees SwiftUI transitively, so "`Presentation` never imports SwiftUI" is no longer true and no longer
claimed. View models stay testable without a host application regardless, since what a test
constructs is the view model, not the view.

## The app icon is three drawings, and the two sets need opposite things

The artwork arrived as three 1024 SVGs — a light diff in the cup, a dark one, and a monochrome —
which map onto the three appearances iOS 26 and macOS 26 render: any, dark, tinted.

Rasterising them is where the care went, because the two platforms want opposite files and each
mismatch is an App Store Connect reject rather than a build failure. iOS needs a **full square with
no alpha sample**: an alpha channel on the marketing icon is ITMS-90717, and the system applies its
own mask — so the artwork is rendered with its squircle clip **stripped**, or the mask would be baked
in and then masked again. macOS needs the **shaped** icon **with** alpha at every slot in the ladder,
because nothing masks a Mac icon for you and empty mac slots emit no macOS icon at all (ITMS-90236).

Quick Look is the obvious rasteriser and the wrong one: it composites onto white, so a shaped icon
comes back with opaque white corners instead of transparency. `Scripts/rasterise-svg.swift` draws
through CoreGraphics, choosing the backing store per platform, and the generator asserts the
resulting PNG colour type on both paths.

The icons are committed but **not** checked by `make verify-generated`, unlike the Xcode project and
the diff fixtures. Rasterising is not reproducible across machines or OS releases, so checking them
would compare a runner's antialiasing against a laptop's and fail on artwork nobody touched.
`make icons` is deliberately manual.

## No snapshot-test CI job until there is UI to render

Aura gates on one and Granita will, but a required check that asserts nothing teaches people to
ignore required checks. It lands with the first `Ui` slice, and `.github/rulesets/protect-main.json`
gains its name in the same pull request — a job missing from that list is a check that can fail
without blocking anything.

## Merging to `main` publishes, and the build number is not ours to set

The Xcode Cloud workflow is live: every squash merge to `main` archives the phone app and delivers it
to TestFlight for internal testers. **A merge is a release**, so the changelog entry and
`MARKETING_VERSION` have to be right before a pull request goes green — a TestFlight build cannot be
un-published, and the only fix is another build. `[ci skip]` in a commit title suppresses the archive,
which is the escape hatch for a docs-only merge.

The workflow itself is **server-side state** on the App Store Connect app record. It cannot be
code-reviewed, diffed or restored from git, and only the App Store Connect API can read it — which
cannot bootstrap it either, because Apple requires the first configuration to happen in Xcode.app. So
a repository with no CI configuration for its most consequential pipeline is expected here rather
than missing.

`CURRENT_PROJECT_VERSION` is a placeholder that nothing should bump by hand.
`ci_scripts/ci_pre_xcodebuild.sh` writes Xcode Cloud's own monotonic run number into it at build
time, because App Store Connect refuses a build number that repeats within a release train — every
build sharing one `MARKETING_VERSION`. Build 1 shipped before that script was on `main`, so it
archived as `0.0.1 (1)`; the script landed immediately afterwards, which is why the second upload did
not collide.

One prompt during setup is worth recording because it looks like a misconfiguration and is not: Xcode
Cloud asks for the GitHub app to be installed on the **`apple` organisation**, listing every
transitive `apple/swift-*` dependency. That is impossible — only an organisation owner can install it
— and unnecessary, because those repositories are public and are cloned anonymously. Apple's app is
installed on `fardavide/granita` alone.

## The Xcode Cloud build number is a team-wide counter, and that is fine

Observed rather than documented by Apple: `CI_BUILD_NUMBER` increments across the whole developer
account, not per app. Granita's first builds were 70 and 71 because another project of Davide's had
reached 69.

Left alone deliberately. App Store Connect requires `CFBundleVersion` to be unique and **increasing
within one app's release train** — every build sharing a `CFBundleShortVersionString` — and does not
require it to start at 1 or to be contiguous. Gaps appear whenever the other project builds, and
that is valid. The only thing lost is being able to read "how many Granita builds" off the number;
buying that back would mean replacing Apple's counter with our own, which is more machinery and a
new way to collide, for cosmetics.

## The CI-skip token silences GitHub Actions too, so it goes in the pull request title

Xcode Cloud and GitHub Actions honour the same token in a commit message. Putting it in a **branch**
commit therefore suppresses the four required checks, and with no bypass on the ruleset that makes
the pull request permanently unmergeable — checks that will never report.

It belongs only in the **squash commit**, where the checks have already run and only the archive is
skipped. Setting it on the pull request title is **not** reliable, and the failure is silent:

- a pull request with **two or more** commits takes its squash subject from the **title**, so the
  token lands;
- a pull request with **one** commit takes it from **that commit's message** instead — and the token
  cannot live there, because it would silence the required checks.

So set it explicitly at merge time and do not depend on which shape the pull request happens to have:

```
gh pr merge <n> --squash --subject "<title> [skip" "ci]"
```

Three attempts were burned learning this. The second failed because the commit message *explained*
the token — prose containing it is indistinguishable from meaning it — and the third because a
single-commit pull request quietly ignored the title. A document describing this must not spell the
token out; the snippet above is deliberately split so that this file does not carry it either.

## The committed Package.resolved is the Xcode union, not SwiftPM's

Adding `swift-snapshot-testing` to the Xcode project broke the Xcode Cloud archive, and the failure
arrived by email after the merge rather than as a red check.

One file, `Packages/Granita/Package.resolved`, is written by two resolvers that disagree. Xcode
treats the local package as the graph root and writes the **union** — the project's remote packages
plus the package's own, 30 pins. `swift build` and `swift test` rewrite the same file with the
package's own dependencies only, 26 pins. Whoever ran last wins.

Xcode Cloud disables automatic dependency resolution and refuses a stale file, so it needs the union.
That is what is committed, `make resolve` regenerates it, and a CI step asserts it still covers the
Xcode graph — because the natural local workflow, running the tests before committing, silently
reverts it.

Rejected: resolving in `ci_post_clone.sh` on every Xcode Cloud build. It would make the committed
file irrelevant and remove the hazard entirely, but automatic resolution is disabled there precisely
to keep archives reproducible, and buying convenience with reproducibility is the wrong trade for the
one pipeline that publishes.

## Three settled gaps in the diff model, and one spec error

Found while planning M1 against the committed fixture corpus.

**SPEC §5.3 was wrong about renames in `--numstat -z`.** It said the format emits "an extra empty
field" before the paths and that a parser should detect a rename by that field. There is no
zero-length NUL field anywhere in the stream; what marks a rename is a **trailing TAB** inside the
first field, so the record spans three NUL fields rather than one. A parser following the old wording
reads every rename as an ordinary record. Corrected in place, verified against the fixture. This is
the first thing in the spec found to be actually incorrect rather than merely incomplete — and it sat
inside a paragraph warning that a naive splitter desynchronises here.

**`DiffLine` gained `needsMeasurement`.** §6 and §10 both require the client to measure
unpredictable lines for real, and §4's model had no field to say which. A plain `Bool`, always
encoded: an absent key meaning false is the ambiguity §8's PATCH body already works around, and
re-deriving the judgement on the client would duplicate the Unicode logic on both sides where a
disagreement is a row-count error in the scroll.

**Control characters count 0 columns, and East Asian Ambiguous counts 1.** Neither is in §6. Read
literally, "everything else counts 1" gives `first\r` six columns for a line occupying five, so every
CRLF line would over-measure — and CRLF is preserved verbatim in `text`, so the CR is content that
renders nothing. Ambiguous characters (`è`, `—`) are narrow in the monospaced fonts the viewer uses,
and flagging them would push ordinary European prose onto the slow measured path.

## The display-columns fixture was committed empty

`case-display-columns.diff` was 0 bytes from the day it was generated. The file it diffs is created
after the baseline commit and was never staged, and `git diff HEAD` shows an untracked file as
nothing at all — so the width arithmetic the entire viewer depends on had no coverage whatsoever.

`make verify-generated` could never have caught it: empty is deterministic, so committed-empty equals
regenerated-empty forever. The generator now stages the file and **asserts the fixture is non-empty**,
which is the check that was missing. The lesson generalises past this one file: a generator that only
proves it ran proves nothing about what it produced.

## Coverage is reported per kind of test, and the second column is regions

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

## The parser reports what the diff text says, and nothing the git layer already knows

A parsed file carries its path, the path it came from when that differs, whether git refused to diff
it, whether it is a gitlink, and its hunks. It deliberately does **not** carry a status or a line
count, even though both are readable from the text: §5.3's rule is that the change set and its stats
come from one comparison with identical options, and a status re-derived here would be exactly the
second, disagreeing source that rule exists to prevent. A staged delete plus an unstaged add is one
rename to the comparison the stats come from — and the per-file diff would have to agree with it by
construction rather than by coincidence.

Binary and gitlink are the exceptions because only the diff text states them: a one-line summary or a
`GIT binary patch` payload instead of hunks, and mode 160000 on the index line.

## The parser never fails, because a truncated hunk is an ordinary input

The size guard hands it the first two thousand lines of a large diff, so a hunk that stops half way
through is what the guard promised rather than corruption. Throwing would turn every large file into
an error. Anything unrecognised is skipped and everything before it is kept, so the declared hunk
counts stay as git wrote them while the body is simply short — which is what lets the client show
"the first N lines" honestly.

Rejected: typed throws with a malformed-input case. It would be a case no caller could do anything
with, on an input the product produces on purpose.

## Splitting diff output on a newline `Character` silently merges every line of a CRLF file

Swift treats CRLF as a **single** grapheme cluster, so splitting on `"\n"` as a `Character` does not
split a CRLF file at all — it returns the whole diff as one line, with no error anywhere. The split
is on the newline **byte**. The CR that remains at the end of each line is content: it is what makes
the file a CRLF file, is preserved verbatim on the wire, and counts zero columns.

This is not theoretical: temporarily reverting the split to the `Character` form turns the CRLF
fixture's four lines into one, which is how the behaviour was confirmed rather than assumed.

## A conflict marker is recognised by state, not by a prefix

A row of `=` signs is a Markdown heading underline far more often than it is a conflict separator, and
tagging one as a marker would render ordinary documentation as a conflict. So a separator or a
terminator only counts as one when an opener has been seen and not yet closed, and the marker must be
exactly seven characters, alone or followed by a label — nine equals signs is content.

Two consequences worth stating. The open-conflict state is held across the **whole file** rather than
reset per hunk, because a conflict region longer than twice the context breaks into two hunks and the
terminator then arrives in the second one. And `|||||||` is recognised alongside the three §4 names,
because the diff3 and zdiff3 conflict styles emit it and an agent's own git configuration may well
select one — a marker we do not recognise renders as content, which is the failure that matters here.

## The word diff measures similarity over non-whitespace tokens only

§6 sets a floor of 0.4 without saying what is measured. Counting the whitespace runs between words
would carry any two lines of similar shape over it — the runs match whatever the words are, so four
words against four different words scores 0.43 on spacing alone. Excluding them, the same pair scores
zero and is left unsegmented, which is what the floor is for: telling a line that was edited apart
from a line that was replaced.

The check is a token-bag overlap rather than the subsequence itself, so the quadratic comparison is
only run on pairs that can pass. A pure indentation change still isolates correctly, because
whitespace remains a token *inside* the comparison; it is only excluded from the similarity score.

## The marker for a missing trailing newline does not break a pair

§6 pairs maximal runs of deletions "immediately followed by" additions. Taken literally, no file
without a trailing newline is ever word-diffed, because git writes `\ No newline at end of file`
between the line it belongs to and the next one — which is every pair in such a file. Runs are
collected past those markers; the markers themselves are never paired and number neither side.

## The invocation must pin the diff path prefixes

The parser removes the leading `a/` and `b/` from every path. That is not ambiguous with a path that
genuinely begins with `a/` — git writes `a/a/file` — but the prefixes are **configurable**, and
`diff.noprefix` in Davide's own git configuration would silently remove the first two characters of
every path in the product with no error anywhere.

§5.1 hardens each invocation against his configuration but does not cover this one. The diff-family
suffix must therefore also pin the prefixes explicitly, alongside `--no-ext-diff` and `--no-color`.
Recorded here rather than fixed in place because the git layer does not exist yet; it is a
requirement that layer inherits, not a preference.

## The Snapshot coverage row is measured over the view layers, not the whole package

The parser landing dropped that row from 72.6% to 32.8% while the project's uncovered lines went from
72 to 73 — the covered line count did not move at all. The phone app links the diff modules through
its connection feature, so five hundred new lines joined the snapshot denominator, and rendering a
view executes none of them. Measured that way the row falls whenever domain code is added anywhere
under the app, which is a fact about the dependency graph rather than about the snapshots, and no
amount of testing the parser could have fixed it.

Scoped to the layers that draw, the row answers the question it exists for: of the code that draws
screens, how much does a baseline put on screen. Davide's call between three options. The Ui kind is
left unscoped, because a behavioural test drives the real app and reaching a repository and a parser
is exactly what it does.

Rejected: ratcheting that row on covered lines rather than a percentage, which would have passed
today and still caught a deleted baseline, but leaves a number in the table that nothing enforces the
meaning of. Also rejected: reporting the row without gating it, which keeps the dilution and loses
the signal.

**A redefinition un-judges its row for one run.** The summary now records what each kind's percentage
was taken over, and the gate compares two numbers only when both were taken the same way. Without
that, changing the measurement fails the very pull request that changes it — for the redefinition
rather than for a regression — and the only way through would be to disable the gate for one merge,
which is the habit this ruleset exists to prevent.
