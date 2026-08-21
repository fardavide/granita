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

## The file tree carries structure and identity, and nothing that changes while it is on screen

A row of the file selector renders a status letter, a name, `+n / -m` and a viewed checkbox, so the
obvious design hangs the whole change record off each leaf. The tree carries an identifier and a
repo-relative path instead, and the rest is joined by identifier one layer up.

Two reasons. The first is that everything omitted **churns while the shape does not**: viewed state
flips under the reader's finger, stats move on every poll, and a structure rebuilt for either is a
structure that was never really about the change record. The second is that the change record does
not exist yet — landing SPEC §4's `FileChange` here would have forced a decision on how an opaque
identifier encodes on the wire, and the spec carries no JSON example to settle it. That belongs to
M2's API contract, not to a grouping function, and guessing it here would have put a wire format in
a module that never touches the wire.

So the tree's input is its own two-field entry: an identifier to hand back when a row is tapped, and
where the file sits. The mapping from a change record is a boundary mapper, which is what boundary
mappers are for.

## The flat toggle is not a second shape the domain owes

§10's file selector has a toggle "to a flat path list", which reads like a second output. It is not
one, and flattening the tree to produce it would be actively wrong.

A depth-first walk of a directory-grouped tree yields **a third order**, agreeing with neither the
tree nor the diff. The change set as it arrives is already git's own path order, which is the order
of the one continuous scroll the detail pane renders — so the flat list is the input list, unchanged,
and tapping the nth row goes to the nth file in the scroll. There is nothing for a domain function to
do.

The tree is therefore the only shape built, and it is the one that reorders.

## Directories above files, and the sort is over what the row reads

Git orders a diff by whole-path bytes, which interleaves the two — `Makefile` lands between `Apps/`
and `Sources/`. A project view does not, and "Android Studio style" is the brief, so directories sort
above files and each group sorts alphabetically.

Case-insensitively, because a case-sensitive comparison puts every capitalised name above every
lowercase one and that is not where a reader looks; with the raw names as a tiebreak so two spellings
of one word still order deterministically. Nothing in the comparison is locale-sensitive: an iPhone
and an iPad showing one worktree must show it identically.

The comparison is over the **compacted** name — what the row actually reads — rather than the first
component of the chain. The two differ only when a separator meets a punctuation character in a
sibling's name, and sorting a visible list by something other than its visible text is the harder
behaviour to explain.

## Compaction folds directories, never a file, and the row is identified by its deepest path

`app/src/main/kotlin/com/example` is one row because each of those directories holds exactly one
child and that child is another directory. A directory whose only child is a **file** is left alone:
the file is content the row contains, not another step of the path, and folding it in would leave
nowhere to render its status, stats and checkbox.

A compacted row is identified by the **deepest** directory in its chain, because that is the row
collapse state has to be remembered against — the chain collapses and expands as the single thing the
reader sees. Its name keeps the separators; its path is the full repo-relative one.

Considered and deferred: aggregate `+n / -m` on a directory row, which a collapsed directory could
usefully show. §10 asks for stats on file rows only, and the aggregate is a sum over a subtree that
the view layer can take when a design asks for it.

## A dead browser is replaced, and only a refusal that repeats is called one

iOS reports a refused local network permission as one of two DNS codes, and 0.0.3 taught the app to
read both as a refusal. That was half right. `PolicyDenied` (-65570) reaches a browser that is still
waiting and means what it says. `DefunctConnection` (-65569) only means the connection to
mDNSResponder is gone — and while that is what a browser created after a refusal sees, it is equally
what **every** browser sees when iOS suspends the app. So Granita accused Davide of a permission he
had granted, on a screen he reached by switching apps and coming back, and then stopped looking
because the stream ended with the accusation. Force-quitting was the only way out.

Decided: a browser is disposable and the session outlives it. A death is followed by a new browser
after a second, and `DefunctConnection` is only called a refusal once three replacements in a row
have died the same way — a refused browser dies as fast as one can be made, a suspended one does not
die again. `PolicyDenied` still means refusal on sight. Once refusal is the diagnosis the
replacements keep coming, five seconds apart, so granting the permission in Settings brings the Mac
back without relaunching.

The cost is about two seconds of "looking for your Mac" before a real refusal is named, bought
against a screen that lies to someone who changed nothing. The browser sits behind a protocol for
this reason and no other: the restart loop is otherwise reachable only by suspending an app on a
physical device, and it is the loop, not the mapping, that was broken.

## The git client asks a closed set of questions, not an arbitrary command line

The obvious shape for "run git" is a subcommand and a list of arguments. It was rejected. The
questions the product asks are fixed by SPEC §5.3 and each carries a flag whose absence is a defect
that produces no error — so they are an enumeration, and the argument vector for each is built in
one place that a test reads as an array.

Two things follow that are worth stating because they look like omissions.

**No exit code reaches the success path.** Two commands answer by failing — `git diff` exits 1 when
it found differences, `rev-parse --verify --quiet HEAD` exits 1 in a repository with no commits —
and the temptation is to hand the caller the code and let it decide. Instead each command declares
which codes count as having answered, and an unborn HEAD is simply an empty answer. What a caller
gets back is bytes and whether they are all of them. That keeps the exit code, which is a fact about
a subprocess, out of a protocol whose whole purpose is that it need not be one.

**The error is allowed to be more concrete than the success path**, and carries git's standard error
verbatim along with the exit code. It is read on a phone by someone who cannot open a terminal, and
a failure that arrives as a bare code is a failure nobody can act on.

## Every configurable part of an invocation is pinned, including the ones that are already the default

§5.1 hardens the invocation against a developer's global configuration, and lists the pager, the
colour setting and the path-quoting rule. Two more were found by reading the configuration keys that
exist rather than the ones the spec names.

**The path prefixes.** M1 recorded this as a requirement the git layer inherits, and it is now
`--src-prefix=a/ --dst-prefix=b/` on every diff-family command. `diff.noprefix` is set in Davide's
own configuration and would take the first two characters off every path in the product;
`diff.mnemonicPrefix` would spell them `i/`, `w/` and `c/` instead. Neither fails.

**The status invocation, in full.** Its bytes are hashed into the worktree's revision, which is the
only thing that tells the phone something moved, so anything that changes those bytes changes when
the phone refreshes. `status.showUntrackedFiles=no` empties the section outright. The collapsed
default is subtler and was verified rather than assumed: with `--untracked-files=normal`, adding a
second file inside an already-untracked directory leaves the output **byte for byte identical**, so
the revision does not move and the phone never learns. `all` is therefore pinned, along with
`--renames`, `--no-branch` and `--no-show-stash`.

The diff-family flags go **immediately after the subcommand** rather than at the end, because
everything past `--` is a pathspec: a flag appended to a vector that ends in a path is read as the
name of another file to diff.

## A fixture repository configured to defeat the product

Every other fixture is built with `GIT_CONFIG_GLOBAL=/dev/null`, which means none of them can tell a
hardened invocation from an unhardened one. The whole of §5.1 could have been deleted and the suite
would have stayed green.

`.fixtures/hostile` puts that configuration in the repository's own config, where a child process
reads it whatever the environment says: no path prefixes, mnemonic prefixes, forced colour,
octal-escaped paths, hidden untracked files, and an external diff tool that fails. The generator
asserts each trap **with the others neutralised**, so one flag going missing from the product cannot
be hidden by another still working — a fixture that quietly stops being hostile makes the git
layer's tests pass for the wrong reason, which is worse than not having it.

Confirmed to bite by removing each pinned flag in turn and watching the suite go red, including the
two real-binary tests: without the prefixes git emits `"a/caff\303\250.txt" "caff\303\250.txt"`, and
without the untracked mode the status carries no untracked file at all.

## An output cap truncates, and truncating means killing git

§5.4 wants a diff that is too large shown as a prefix with a flag, not refused. So the cap is not an
error: the client returns what it read and says it is a prefix.

Stopping the read is only half of enforcing it. A macOS pipe buffers 64 KiB and the cap permits two
megabytes, so git is still writing into a pipe nobody is emptying and blocks there forever — the
hang is on exactly the large diffs the guard exists for. The process is torn down as part of hitting
the cap, which in turn means a truncated run's termination status describes our own signal and must
not be judged: judging it would turn every large diff into a failure.

The same teardown serves the timeout, and neither ever signals a process **group** — a child gets
this process's own group, so signalling the group signals the menu bar app.

## Arguments are bytes, and so is a repo-relative path

A path on disk is a sequence of bytes with no encoding attached. Decoding one to build an argument
vector substitutes a replacement character, and re-invoking on the result addresses a file that does
not exist — silently, because U+FFFD is a perfectly ordinary filename character.

So the vector is `[[UInt8]]` and a repo-relative path carries its bytes, with text as the lossy
projection for display and for the wire rather than the other way round. This is the shape M1
anticipated when it gave `FileID` a byte-based derivation.

The checkout's own location stays a string. It comes from `git worktree list` or from Davide picking
a folder, it is never accepted from a client, and treating a directory Davide chose as undecodable
buys nothing.

## An opaque identifier is a bare string on the wire

The second requirement M1 recorded and left open, and the spec carries no JSON example to settle it.
Decided: a bare string, not `{"rawValue": "…"}`.

The synthesised encoding of a one-field struct is the object, which is why this had to be decided
rather than inherited. The wrapper exists to keep three kinds of hash from being interchangeable at
compile time; it is not a shape the wire owes anyone, and an identifier has to be a string to serve
as a path component in a URL and as a key in a JSON object. `RawRepresentable` says the first part
and `CodingKeyRepresentable` the second — without it a dictionary keyed by an identifier encodes as
a flat array of alternating keys and values, which no other client would read as a mapping.

`FileChange` itself does not land with this. It needs a content hash, a status and a line count,
none of which exist until the change-set slice, and the decision this was blocking was the encoding
rather than the struct.

## What the first git slice deliberately leaves out

Two things from §5.3 are absent, and neither is an oversight.

**Resolving the git binary.** §5.1 wants `/usr/bin/git`, then `xcrun -f git`, then `PATH`, with a
clear error in the Mac UI when there is none. The middle step is itself a subprocess, so a locator
worth testing needs its own seam, and it belongs with the composition roots that will call it. Until
then the executable is a constructor parameter, and a path with no binary at it surfaces as git
being unavailable.

**`hash-object --stdin-paths`.** The only command that writes to a child's standard input, and the
only one with an unresolved correctness question: `--stdin-paths` reads one path per line, so a path
containing a newline needs C-quoting on the way in. That question belongs to §5.5's content hashing
rather than to the client, and adding the case later changes no signature.

## The rest of M2, and the three things real repositories said that the spec did not

### `cwd` is not on every session record, and there is no `summary` record at all

SPEC §7 describes both. Read against the 117 real transcripts under `~/.claude/projects` on
2026-08-21: `cwd` appears on `user`, `assistant`, `attachment` and `system` records and on none of
the six other kinds — one of which is routinely the *first* line of a file, so a reader taking the
first record's `cwd` gets nothing. And across 400 files there are **zero** `summary` records against
4,468 `custom-title` and 10,023 `last-prompt`. `custom-title` is the analogue and is what a label
prefers now; `last-prompt` is deliberately unused, because the most recent instruction names what a
session got down to rather than what it is about.

§7's `projects/*/*.jsonl` turns out to be exactly right and worth defending: one level below the
sessions are 1,237 subagent transcripts sharing their session's `cwd`, whose opening turn is a brief
nobody typed.

### A session belongs to one worktree, so the matching is decided over all of them at once

Every worktree an agent creates lives *under* the checkout it branched from, so "is this session's
directory inside this worktree" answers yes for the outer one every single time. Asked per worktree,
the primary checkout takes the name of whatever was last done in any worktree beneath it. Each
session is therefore assigned to the closest worktree containing it, and only then does each
worktree pick its best session. Containment stops on a separator, or `/repo/slice` claims
`/repo/slice-two`.

### A nested worktree is an untracked *directory*, and hashing it fails the whole batch

`ls-files --others` does not descend into another repository: it reports the whole thing as one
entry with a trailing separator. Claude Code puts every worktree it makes under
`.claude/worktrees/`, so the primary checkout of any project an agent has touched has one — and it
is not a file. Left in, it is an added file nobody can open; worse, `hash-object --stdin-paths`
refuses it and **the whole batch fails**, which took the entire change set down with it. Found by
running the server against the fixture repository rather than by reading anything. A deleted file
and a submodule are excluded from the batch for the same reason.

### An unborn HEAD is forty zeroes, not an absent line

`worktree list --porcelain` reports it as `HEAD 0000…` on a line present like any other, so a reader
checking whether the line exists concludes that a repository with no commits has one.

### The change set carries a byte path the wire does not

`FileChange.path` is a lossy decoding for display; re-invoking git on it would address a file that
does not exist. The change set therefore carries a separate identifier-to-bytes map, off the wire,
and anything that goes back to git looks the path up there.

### No exit code, but the error is allowed to be concrete

Stated when the git client landed and it held: what a caller gets back is bytes and whether they are
all of them. The failure path is the exception — it carries git's standard error verbatim and the
exit code, because it is read on a phone by someone who cannot open a terminal.

### Auth is off under `--insecure-http`, and that is not a hole

A token over plaintext is a token everyone on the network already has, so demanding one would be
theatre. The flag exists so a TLS problem can never leave code unreviewable, it is off by default,
and it is never reachable from the Mac app's UI. TLS itself, the Keychain identity and SPKI pinning
are M3's, where SPEC §12 puts them.

### Timestamps are ISO 8601, and that is asserted rather than assumed

The date format on the wire is currently whatever the HTTP framework's encoder defaults to. A test
reads the raw JSON and checks it parses as ISO 8601, so a framework upgrade that switches to
seconds-since-epoch is a red test rather than a phone showing every worktree as modified in 1970.
Pinning the encoder explicitly is worth doing when M3 next touches this module.

## Claude Design is asked with baselines and prose, and nothing is uploaded to it

Oltre's design loop is the model this borrows from, and its central part transfers unchanged: the
ask is a **round trip** rather than a hand-off, so the session that writes the prompt waits for the
frames and then builds them. The `design-handoff` skill carries that.

**Two parts do not transfer, and they are the decision.**

**The prompt is not a file here.** Oltre commits one per round trip under `.claude/prompts/`, as a
dated record of what was asked. Granita tried that and Davide rejected it the same day: *"You give
prompt in chat in code block, not in files. If we need to attach image, you place them on desktop."*
He is right about what the artefact is. A prompt is pasted once, into another tool, within the
minute — putting it behind a pull request puts a review gate in front of a clipboard, and on `main`
here that means four required checks. What is worth keeping is the **answer**, which this file and
the docs already have a home for. The cost accepted is that the exact wording of an ask is not
recoverable later; the calls it produced are, and those are what get re-read.

**And Oltre lifts its own colour tokens** into a Claude Design project so a frame is composed from
the same palette the app draws with.
Granita has no design-system module and will not grow one for v1 — the palette is semantic system
colours, the icons are SF Symbols, and every control on screen is a stock one. There is nothing to
upload, and uploading a synthesised stand-in would be worse than nothing: it would invite frames
built from a vocabulary the app does not have, and `swift-style` already forbids both the hardcoded
colour and the hand-rolled control that would be needed to build them. So the prompt names the
idiom instead, and asks for decisions inside it — hierarchy, what a row says, what an empty state
offers, which of two readings wins — rather than for a look.

**What goes over as the drawing is the committed snapshot corpus**, copied to the Desktop to be
attached, all four layouts of each state. The alternative considered was a hand-drawn mock, which
is faster and is an unchecked claim about what the app looks like; a baseline is the only image of
this app that something re-renders and compares. It is also why a screen built from a returned frame
lands with its baselines in the same pull request: they are what makes fidelity checkable later
rather than asserted once.

The cost is accepted and named: a surface with no snapshot suite — the Mac settings window, today —
can only be described, so what comes back for it is a first drawing rather than a review. Those two
kinds of ask are numbered separately inside a prompt rather than blurred together.

## One model per unit, not one per view

Davide's correction, 2026-08-21, on seeing a `MenuBarViewModel` and a `ConnectionLogViewModel` land
beside each other in the same module: **a state object per view is a vertical split wearing a
layer's name.** The menu bar item and the Settings window are two views onto one running server, and
splitting that server's state across as many objects as there are places it is drawn puts the seam
in the wrong direction — a screen, rather than a layer.

So a unit's `Presentation` holds **one** `@Observable` model, named for the unit rather than for a
screen: `ServerMacModel` carries what the server is doing and who has reached it, and the four
Settings tabs M3 still has to build add properties to it rather than a type each. Views stay
stateless and are handed values, which is unchanged — that direction was already settled when
`Presentation` was put above `Ui`.

The cost is a type that grows, and it is worth naming: if one model stops being readable, the split
is by **layer concern** — what it wraps — and never by which screen happens to draw it. What is
gone is the reflex that a new screen needs a new state object.

The phone still has `ServerDiscoveryViewModel` from M1, and it is deliberately left alone rather
than swept: the rule is written here and in the architecture skill, and each module converts as it
is next opened. M4 reopens the client's connection feature and converts it there.

## The composition root is its own module, and coverage is measured over what a test can reach

Two things landed together because the first is what makes the second expressible.

**`ServerAppPresentation`, which the spec's §3 tree does not list.** The menu bar app's wiring lived
in `Server/Mac/Presentation` beside the model it builds. That module was then both a feature's
presentation layer and a composition root — one of them full of things a test constructs, the other
full of things no test can. It is now split the way the client already was: `Client/App/Presentation`
has always been the phone's composition root, and `Server/App/Presentation` is the Mac's. The
feature module loses its `Data` dependencies with it, so `Presentation` no longer sees `Data`
anywhere except in the two roots and the executable — which is what the layer rule always said.

**Then the coverage gate.** Adding the Mac's first test target pulled `ServerMacUi` and the
composition root into the unit denominator for the first time and dropped the Unit row 11.7 points
in one pull request. Nothing had got worse: a SwiftUI body needs a renderer and a SwiftPM test
target is hostless, and no test constructs a composition root, so those lines are uncoverable by
construction rather than uncovered by neglect. The number moved because a module was linked into a
test binary — a fact about the target graph, and the same class of dilution that scoped the Snapshot
row to the view layers.

So the Unit and All rows are now measured over **what a host test can reach**: the package, minus
view bodies, minus the composition roots. It is the mirror of the Snapshot row's scope rather than a
new idea, and the gate un-judges a redefined row for exactly one run, which is the mechanism that
exists for this.

`granita-server` was already exempt by accident — an executable target is not linked into a test
binary, so its composition root has never been measured at all. Naming the directories makes that
the same decision for all three rather than a property of how one of them is packaged.

**What this leaves open, deliberately.** A macOS view layer is now measured by nothing: the Snapshot
kind is the iOS target, and there is no macOS equivalent. That is tracked in `status.md` and it is
owed before the Settings window grows its other three tabs — each one is a screen that a host test
cannot execute, and the Unit row will keep drifting down until a kind exists that renders them.
Screens composed in `Presentation` have the same problem in miniature and are counted today, which
is the honest reading: they are reachable in principle, and nothing renders them yet.

## The calls outlive the drawings, and the drawings are deleted as they are built

The four client screens were reviewed and redrawn on 21 August 2026, against 0.0.4 as shipped. The
calls live in [`design.md`](design.md) and the `design` skill makes consulting them binding before
any client SwiftUI. The frames live in [`design/`](design/) **only until the screen exists**.

Two halves with opposite lifetimes, and conflating them is the mistake this entry exists to prevent.
The prose is **kept**, because a review whose alternatives are only in someone's session gets
re-litigated the first time an agent has a different idea — every call names what it beat, for the
same reason the entries in this file do. The frames are **working material**, and are removed by the
pull request that implements their section. Davide, 2026-08-21: *"We're not saving design as a
documentation, we're saving actual design for the upcoming implementation. Once implemented, they
are gone."*

What replaces a deleted frame is not nothing: it is the committed snapshot baselines, which are the
only artefact that can be compared against what was returned. A drawing kept beside them is a second
answer to a question that now has a real one, and the two drift.

§1's frames went this way in 0.0.6, with the screen. §2, §3 and §4 remain because they are not built.

### The rename sheet offers the session suggestion; it does not prefill it

The one place the design contradicts `SPEC.md` §10 outright, recorded here because that is what this
file is for. The spec says the rename sheet opens with the suggested alias prefilled. It will
instead open **empty, with the derived name as the placeholder, and the suggestion offered as a
tappable row**.

Prefilling means the reader's first act in every non-accepting case is to select-all and delete 51
characters on a phone keyboard, and a prefilled field cannot distinguish "I accepted the agent's
summary" from "I named this". Offering costs one tap in the accept case. The section footer states
what the row will read after Save and updates live, which is what makes an empty field legible
rather than mysterious. Lands with M4.

## A failure carries a diagnostic, not advice

`DiscoveryState.failed` used to carry `error.localizedDescription`, and the discovery screen put it
in the one line a reader acts on. That handed the screen's advice to Network.framework, which writes
"The operation couldn't be completed" — true of every failure there has ever been, actionable in
none of them.

The payload is now labelled a **diagnostic** and rendered at the bottom in small monospaced
selectable print, with the raw `NWError` code appended, while the description above it is ours and
fixed. The code is the only part of that string anyone can act on, and the reader of this app is the
developer of it.

Rejected: hiding the diagnostic behind a disclosure, which is a tap to reveal four words nobody can
use; and an alert, which demands an answer to a question the reader was not asked and leaves the
same empty screen behind it. This is a state of the screen, not an interruption.

### A defunct connection while *waiting* now reports searching, not failure

The design asks for policy errors to be routed away from the failure state and rendered as a
refusal. Applied literally to the waiting path that would re-open the bug 0.0.4 fixed: a defunct
connection is the code that means *either* a refusal seen by a browser that was not the app's first
*or* a process that has just been resumed, and telling those apart is what the death counting is
for. Reporting it as either verdict from the waiting path reaches the screen ahead of the counting.

So the waiting path stays silent on that one code and reports searching, which is what is actually
true; the death path still counts, and three deaths in a row is still a refusal. The literal reading
of the design would have accused a reader of a setting they did not change, which is the exact
failure `BrowserRestartPolicy` exists to prevent.

## Selecting a Mac is a navigation link with no destination yet

§1's headline defect was the discovery row built from a label-and-value pair, which resolves width
pressure by dropping the "value" — here a disclosure chevron — onto its own line, 300pt from where an
indicator belongs. The row is now a value-based `NavigationLink`, which supplies the indicator, pins
it to the trailing edge at every type size, gives the correct pressed state, and draws no chevron at
all once this list becomes the split-view sidebar in M4.

The consequence is that the `Ui` layer no longer reports the selection and the composition root has
no `navigationDestination` for a discovered server, so tapping a Mac does nothing. That is what
tapping a Mac already did — the callback was a no-op, because selecting a Mac *is* pairing and
pairing brings the Keychain identity and the QR code with it. Chosen over deferring the fix until
pairing exists, which would have left a shipped bug shipped and asserted as correct by the baselines.

### Where the design review contradicted itself, and how it was read

Two places where §1's prose and its own drawings disagreed. Settled with Davide rather than by
picking whichever was read last, and folded back into `design.md` so the document no longer holds
both readings.

- **The Mac row is one line, not two.** The prose asked for a two-line limit with middle truncation;
  the frame drew one line, middle-truncated; and the paragraph below rejected "a two-line wrap with
  the chevron centred" for making a 68pt row. A two-line limit does not truncate a long device name
  at 390pt — it wraps it, producing precisely the rejected layout. One line, so every row is the same
  height.
- **The iPad measure goes around the navigation container.** The prose asked for the large title to
  sit inside the 420pt measure. iOS draws a large title in the navigation bar rather than in the
  content, so clamping the screen centres the rows and leaves the title at the window's leading edge.
  The composition root clamps the stack instead, and the snapshot suite clamps on the same side so
  the baselines assert what ships. Rejected: hand-rolling the header inside the column, which buys
  exact alignment by giving up a system control.
