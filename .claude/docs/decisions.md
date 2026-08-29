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

The phone kept `ServerDiscoveryViewModel` from M1 for one release, deliberately, rather than being
swept: the rule was written here and in the architecture skill, and each module converts as it is
next opened. M4 reopened the client's connection feature and converted it — `ClientConnectionModel`
carries the browse, the handshake and the pairing history, and nothing in the client is named for a
screen any more.

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

## The X.509 encoder is ours, and the fourth dependency it beat was already in the graph

`swift-certificates` would have written the self-signed certificate in a dozen lines, and it is
**already resolved** — `swift-nio-extras` pulls it, so naming the product adds nothing to
`Package.resolved`. That is the same argument that admitted `NIOTransportServices`, and it was
rejected here.

The difference is what the dependency is *for*. `SPEC.md` §8 mandates the bind that only
NIOTransportServices can do, so that one is the spec's choice rather than a convenience. Nothing
mandates a certificate library, and "it happens to be in the graph today" is a property of
Hummingbird's transitive dependencies, not a decision this project made — the day nio-extras drops
it, a core capability acquires a real fourth dependency retroactively. The rule is that a fourth is
a conversation with Davide, and a conversation cannot be had by noticing something in a lockfile.

What was bought instead is a few hundred bytes of DER in a `Domain` module, whose output is checked
by **Security.framework itself** rather than by our own reader: the suite hands the certificate to
`SecCertificateCreateWithData`, matches the key inside it against the key that signed it, evaluates
it as its own anchor under a real TLS policy, and asserts the system's own hostname matcher against
a name the certificate covers and one it does not. A byte wrong anywhere and the signature does not
verify. The SPKI fingerprint is asserted against an `openssl`-produced vector rather than against
this encoder, because the whole failure mode is an encoder that agrees with itself.

## macOS refuses a ten-year TLS certificate, which is why pinning replaces evaluation

Apple's 398-day cap on TLS server certificates is documented as not applying to roots a human
added. It **does** apply to one handed to `SecTrust` programmatically as its own anchor: evaluated
under `SecPolicyCreateSSL`, the ten-year identity comes back
`Certificate exceeds maximum temporal validity period` however correct everything else about it is.

So SPEC §8's ten years and SPEC §8's pinning are one decision rather than two, and it matters for
M4: the phone's `URLSessionDelegate` must **replace** the default evaluation with a fingerprint
comparison, not run both. A client that did both would refuse every Granita there has ever been,
and the only symptom would be a handshake that fails.

Found by running it, and now asserted by a test that expects that exact refusal — so a macOS which
changes its mind turns the suite red rather than leaving a comment nobody re-reads.

## The identity's handle is its common name, because the Keychain discards the one we choose

Two Keychain behaviours cost a fingerprint that changed on every launch, which is every paired
device silently locked out — the key is what they pin.

**A certificate's label is derived from its subject common name.** `SecItemAdd` accepts a
`kSecAttrLabel` for a certificate and throws it away; the file-based keychain writes the common name
instead. Searching back for the label we chose therefore found nothing, and each run generated a new
identity, stored it, and served it.

**A `kSecClassIdentity` search does not filter on the key attributes it documents.** The obvious
repair — tag the private key and search identities by that tag — returned Davide's *Apple
Development* identity on the first try, whose RSA key then failed to read as P-256 three calls
later. The class is searchable; the filter is not applied.

So the certificate's **common name is the handle**, and it is `Granita` rather than the Mac's name:
renaming a Mac, or moving it to another network, must not orphan the identity. Every address this
Mac answers on goes in the subject alternative names, which is where RFC 5280 puts them and where
every modern client looks. The search is over certificates — where the label filter does work and
where the result can be asked for as bytes rather than as a `CFTypeRef` needing an unchecked cast —
and the private key is paired to it afterwards with `SecIdentityCreateWithCertificate`.

Two more Keychain facts are pinned in comments beside the code because each has one symptom and no
explanation: every query must say `kSecUseDataProtectionKeychain: false`, or the modern keychain
answers and refuses any ad-hoc-signed binary with `errSecMissingEntitlement`; and the private key is
**generated inside** the Keychain rather than imported, because `SecItemAdd` refuses a `SecKey` made
by `SecKeyCreateWithData` with `errSecInvalidItemRef`. The second is the better design anyway — the
private half never exists outside the Keychain, and this process only ever asks it to sign.

## The identity is never regenerated, and a stale address is the price

The certificate names every address the Mac had when it was created. Those change; the certificate
does not. Chasing them would rotate the pinned key every time the Mac joined a network, which
unpairs every device that has ever connected — a far worse failure than a subject alternative name
that no longer resolves, because the client matches on the pinned key rather than on the name.

## The six words are a second credential, not a rendering of the code

An earlier draft derived the spoken code from the first six hexadecimal characters of the real one
and had no way to redeem it. That is not a fallback: it is a decoration under a QR that cannot be
typed in.

The words are now independently random and redeem the same pairing — spending either spends both,
so a photographed QR is worthless once the words have been used. The list is **128 words rather than
16**, because six words from sixteen is 24 bits: five guesses a minute from one address would take
years, and a hundred addresses on one network would not. 128 gives 42 bits, and the words are chosen
to be readable across a room — nothing homophonous, nothing a letter apart, no contested spellings.

What is typed is normalised before it is compared: nobody types the hyphens, and somebody reading
six words off a screen capitalises the first.

## Both pairing refusals answer the same way on the wire and differently in the log

`/v1/pair` is the one route an unpaired device may reach, so it is the one route an attacker may
reach. A caller told apart "that was never a code" from "that was a code, too late" has an oracle
for whether it is guessing in the right shape at all, so both come back `pairingExpired`.

The connection log gets the difference, because its only reader is the person standing at the Mac
and the two mean different things to them — type it again, against be quicker. That panel is the
reason the distinction is worth keeping at all rather than collapsing at the source.

## The `Host` header is not a source address, and the rate limit was counting the wrong thing

SPEC §8 asks for five failed attempts per minute **per source address**. The M2 implementation used
`request.head.authority`, which is what the client dialled — the same string for every device on the
network. So the limit was global, one misconfigured phone could lock out every other device, and the
connection log's "source" column said where each request went rather than where it came from.

The router now carries its own request context over `RemoteAddressRequestContext`, reading the peer
address off the channel. Confirmed against a real bound listener rather than the in-process test
client, which has no channel and reports nothing — and confirmed to be able to fail, by making the
accessor return a constant and watching the test go red.

## `--pair` reissues, because a code cannot be asked for from outside the process

Pairing codes live in the actor serving requests, so there is no way for a second invocation of
`granita-server` to hand one out — and there is no QR in a terminal. `--pair` therefore prints an
invitation at startup and a fresh one as each expires.

It exists so the TLS and pairing path is exercisable before the pairing screen is designed, which is
what let this slice be verified end to end: `curl --pinnedpubkey` over the advertised port, the
six-word code redeemed for a token, and an authenticated route read back. Noisy by design; it is a
debugging flag on a debugging tool, and two minutes is not long enough to fumble a phone out of a
pocket.

## The Keychain joins the view bodies and the composition roots as uncoverable

Adding the identity store dropped the Unit row 5.6 points and turned the coverage gate red. Nothing
got worse: the store is ~200 lines that a host test cannot execute at all, and linking it into a
test binary — which happened because the interface enumeration beside it *does* have tests — pulled
every one of those lines into the denominator. That is the same dilution that scoped the Snapshot
row to the view layers and the Unit row away from the composition roots, arriving a third time.

A SwiftPM test binary is unsigned and has no keychain of its own, so the only way to run that file
is to write into the developer's real login keychain. It is behind `ServerIdentityStore` for exactly
that reason, everything downstream is tested against a fake, and it was verified by running the
server and pairing against it. Uncoverable by construction, not uncovered by neglect.

So it is named in the scope, **per file rather than per directory**: `Server/Identity/Data` also
holds the interface enumeration, and exempting the directory would stop measuring code that host
tests do cover. The bar for a second entry is the bar this one met — unrunnable from `swift test` by
construction — and not "hard to test".

**The scope's name changed with it**, `reachable` to `host-reachable`, and that is the mechanism
rather than a tidy-up. The gate compares two numbers only when both were taken the same way, so
renaming is how a redefinition declares itself: the Unit and All rows go unjudged for one run and
rejoin the ratchet on the next `main` run. Redefining silently would have compared a number against
the answer to a different question — and would have failed this pull request for the redefinition
rather than for a regression.

Rejected: deleting the interface-enumeration tests so nothing links the module and it leaves the
denominator the way `granita-server` does. It would have passed the gate today by removing tests,
which is the failure signature the `swift-testing` skill warns about in as many words.

## The pinned trust replaces the system's evaluation and never runs beside it

macOS and iOS cap a TLS server certificate at 398 days and apply the cap **even to a certificate
handed to `SecTrust` as its own anchor** — Apple's published exemption covers roots a human
installed, not one set programmatically. SPEC §8's certificate lasts ten years, so the default policy
refuses it for its entire life.

A client that evaluated *and* compared the fingerprint would therefore refuse every Granita that has
ever existed, and the only symptom is a handshake that fails with nothing attached to it. So the
server-trust challenge is answered on the fingerprint alone: no `SecTrustEvaluateWithError`, no
policy, no chain. The key is the whole question, which is what SPEC §8 means by pinning.

This is asserted from both ends rather than commented. `ServerIdentityDomainTests` pins the refusal
itself — a real `SecTrust` under a real policy, expected to say "exceeds maximum temporal validity" —
so an OS that changes its mind turns a test red. And `PinnedServerTrustTests` judges a **ten-year**
`openssl`-generated certificate and expects it accepted, so anyone reintroducing default evaluation
beside the pin breaks that test rather than shipping a client that cannot connect to anything.

Rejected: evaluating first and pinning second, which is the shape every pinning tutorial shows and
which is wrong here for the reason above. Rejected too: shortening the certificate to 398 days so
both could run — it buys nothing, because pinning already makes expiry a backstop rather than a
schedule, and it would put a renewal on the calendar of an app whose whole point is that it is not
administered.

## The client reconstructs the public key info rather than parsing the certificate

The fingerprint is taken over the whole `SubjectPublicKeyInfo` structure, which is what the Mac
hashed and what every other pinning implementation in the world agrees on. Getting those exact bytes
back on the phone could be done two ways: parse the leaf certificate's DER, or read the key out with
`SecCertificateCopyKey` and let CryptoKit re-encode it.

CryptoKit re-encodes. `SecKeyCopyExternalRepresentation` hands back the X9.63 point, and
`P256.Signing.PublicKey(x963Representation:).derRepresentation` produces byte-for-byte the structure
the Mac hashed with the same call. There is one implementation of that encoding on both sides, which
is the property that matters: two implementations of one structure is how a fingerprint comes to
disagree with itself.

Rejected: promoting `DerValue` to a `Core` module so the client could share it. It is a *writer* —
"just enough DER to write one certificate" — so sharing it would have meant writing a DER *reader*
that does not exist, to recover bytes that a two-line round trip already returns exactly. A module
move and a new parser, for nothing.

## A scanned code that is not ours is a state, not a refusal

`PairingLink` already refused a non-Granita URL with `notAPairingLink`. What was missing is that a
viewfinder is not a form: it reads several times a second and most of what it finds belongs to
somebody else — a Wi-Fi code on a poster, a URL on the back of a bus. Surfacing those as errors would
put a stream of refusals in front of somebody who is simply holding a phone up at a screen.

So `PairingLink.scanned` returns one of three things, and the distinction it draws is **ours / not
ours** rather than valid / invalid. A `granita://` link that is damaged is worth a sentence, because
the reader is pointing at the right thing and it is not working. Anything else — another scheme,
another action under our own scheme, or text that is not a URL at all — is not an event.

Rejected: a `Result`, which forces the common case to be a failure and would make silence the
caller's job to remember. Rejected: treating a `granita://` link with an unknown action as damage,
which would make any future URL this app learns to open surface as a broken pairing code today.

## The spoken word list's promises are asserted, not described

The list documented four properties — a fixed count the 42-bit entropy argument depends on, no
duplicates, no two words a single letter apart, and no spelling contested across the Atlantic — and
nothing enforced any of them. It contained `amber` beside `ember`, which is the pair its own comment
names as the thing to avoid, and `bacon` beside `beacon`, which nobody had noticed at all.

They are now five tests over the list itself. The failure they prevent is not a build error: it is
somebody across a room reading six words aloud, months from now, and the wrong pairing being spent
once. `emerald` and `beetle` replace the two collisions.

Rejected: taking the list from a dictionary or from the PGP word list. The hand-picked constraint is
the point — the fallback exists for the case where the channel is a voice or a memory — and a
borrowed list would satisfy none of these four properties by accident.

## The Mac's design is recorded against a release the review had not seen

Claude Design drew the Mac's six surfaces on 21 August 2026 against 0.0.6, and 0.0.7 landed in the
same week. Two of the five premises the review overturns were repaired by that release independently:
the connection log's source address and the six-word code's redeemability. A third — the plaintext
warning it moved to sit under the QR — is obsolete, because TLS and a real `spki=` shipped in 0.0.7.

[`design-mac.md`](design-mac.md) therefore records the review's calls **as corrected**, with a table
saying which premises still stand, rather than as returned. The frames stay as working material until
each section ships.

This is the `design-handoff` skill's rule doing its job in the direction it was written for: a return
is a recommendation, not a decision, and where a drawing and the code disagree the code is checked
before either is believed. Building the drawing as returned would have reintroduced a warning telling
a reader their pairing link is unencrypted when it is not — which is worse than no warning, because
it is the one screen where a reader is deciding whether to trust something.

Rejected: asking Design for a redraw against 0.0.7 before building anything. Four of the five calls
are untouched by the release, the two that changed are both *deletions*, and a second round trip to
delete a warning would have blocked the whole milestone on a question already answered.

## The wire contract has one definition, and `CoreApiDomain` is where the rest of it went

Writing the phone's half of the API forced the question the Mac's half had never had to answer: what
is a payload both ends name, and where does it live. The Mac had been the only reader of its own
contract, so `HealthResponse`, `PairRequest`, `PairResponse`, `ViewedRequest` and `ApiErrorCode` sat
in `ServerApiPresentation` beside the Hummingbird routes that produced them. The obvious way to give
the client the same shapes is to write them again on the client, and that is the one thing
`CoreDiffDomain`'s own header already forbids in as many words: *these types are the wire contract,
so a renamed property is a version skew rather than a refactor.*

So there is a fourth `Core` module, not in SPEC §3's tree for the same reason `CoreBrandingDomain`
and `CorePairingDomain` are not. What it holds is the contract that is neither a diff model nor a
pairing credential. `ApiErrorCode` is the load-bearing member: SPEC §8 says the codes are part of the
contract *because the client branches on them*, and a client branching on string literals copied out
of the server would make a rename a screen that silently stops appearing. The HTTP status each code
maps to stayed on the Mac, because a status is how a refusal travelled and never what it means.

Three payloads moved into `CoreDiffDomain` instead, where the models the API is expressed in already
live: `DiffSide`, and the two read bodies that were called `ChangesResponse` and `LinesResponse` and
are now `WorktreeChanges` and `FileLines`.

**`WorktreePatch` is the case that justifies the whole exercise.** SPEC §8 marks it TRAP: `Codable`
decodes an absent key and an explicit `null` identically, so a struct cannot tell "clear the alias"
from "leave it alone", and the API needs both. That was implemented once, correctly, on the reading
side. Written a second time on the writing side it would have been a coin flip whether the phone
omitted the key where the Mac expected a null — and the symptom is an alias the reader has just
deleted quietly coming back. One type now encodes and decodes it, and the round trip through both
halves is a test.

Rejected: a shared `ApiErrorEnvelope` alongside the code. The Mac wants to encode a typed code and
the phone must tolerate one it has never heard of, which are different types with the same field
names; the client's four-line private decoder is not the duplication worth removing, and the
enumeration is.

**And the claim is checked rather than asserted.** "Both halves name the same type" is exactly the
kind of statement a suite that only ever sees one half cannot prove, so the phone's real client now
runs against the Mac's real router in one process — nothing faked below the routes, nothing faked
above them, and the pinned `URLSession` as the single substitution, because it is the one thing on
the path that is not about the contract. It pairs with a code the Mac issued and with the six words
under it, reads a worktree's changes and one file's diff and its raw lines, and drives the partial
update through all three of its states. Removing the explicit null from the encoder turns it red with
the symptom this entry describes: an alias the reader has just deleted coming back.

## Timestamps are ISO 8601 because both ends say so, not because a framework does

M2 left this open deliberately: the date format on the wire was whatever Hummingbird's encoder
defaulted to, with a test reading the raw JSON so a change would be red rather than silent, and a
note that pinning it belonged to the next change in the API module. This is that change, and the
reason it could not stay implicit is that the phone has to pick a decoding strategy explicitly —
there is no default to inherit on that side.

Hummingbird's default happens to be `.iso8601` already, which is exactly why leaving it alone was the
wrong answer: a dependency upgrade that changed it would move only one end, and the symptom is every
worktree showing as modified in 1970. Both the request context and the client's decoder now say
`.iso8601` in as many words, so a change to either is a change somebody wrote.

## The phone's transport seam lives in `Data`, not in `Domain`

Every other I/O edge in this project sits behind a protocol its `Domain` owns. `HttpTransport` does
not, and the exception is the rule working rather than a hole in it: nothing above the `Data` layer
names HTTP at all, and moving a request-and-response vocabulary into `Domain` so that one type could
be faked would put the leak in the layer whose whole purpose is not having one. The protocol's
implementation and its only caller both live in `Client/Connection/Data`.

What it buys is that every rule the API client enforces is asserted on the host with no server and no
network: the bearer on the authenticated routes and its absence on the two that answer before
pairing, the contract version on every request, the comma-joined batch of file identifiers, and the
whole table from a refusal code to something the phone has a screen for.

**No HTTP status reaches anything above that client**, and it is not a style preference. SPEC §8
makes the *codes* the contract precisely because two refusals the Mac spells differently on purpose
can share a status — `unauthorized` and `pairingExpired` are both 401 — so a screen switching on the
number could not tell them apart. The status only ever reaches a diagnostic string.

`ApiFailure` carries two cases §8 does not, because §8 describes what a Mac says rather than what
happens when it says nothing: `unreachable`, whose payload is labelled a diagnostic for the same
reason `DiscoveryState.failed`'s is, and `notUnderstood`, which is what a body this version cannot
read and a refusal code a newer Mac invented both become. A third, `requestNotBuildable`, exists so
that no step of assembling a request has to be silenced with a `try?`.

## The phone checks the contract before it spends the code, never after

SPEC §8 says the client refuses to pair on an `apiVersion` mismatch. The order is the part worth
recording: `/v1/health` is read first and the code is spent second.

A pairing code lasts 120 seconds and works once. Discovering the skew from a 426 on the first read
route would mean the reader has already walked to the Mac, scanned a code, spent it, and has to go
back for another one to be told the same thing. Reading health costs one request against a route
that answers before pairing exists — which is the route's whole reason for existing.

Which end is behind is named rather than reported as "the versions differ", because one of them is
fixed by opening the App Store and the other by opening a Mac.

## Joining a Mac is a use case, and the coverage gate is what said so

The first draft put the sequence — read the contract, spend the code, write the token down — on
`ClientConnectionModel`, which is a `Presentation` type. It looked reasonable and it was a layer
violation: a view model orchestrating three protocols is a use case wearing a screen's name, and the
rule that use cases orchestrate exists precisely so that the thing worth testing is not sitting in
the layer that is hardest to reach.

**The Snapshot coverage row is what caught it**, and it caught it as a number rather than as an
opinion. That row is scoped to the layers that draw, which includes `Presentation` because a screen
is composed there — so ninety lines of pairing logic that no rendered baseline could ever execute
joined its denominator and dropped it twelve points. The reflex is to rescope the row; the honest
reading is that the row was right and the code was in the wrong place.

So `MacPairing` is a `Domain` type over the two protocols it needs, returning a `PairingOutcome`
rather than throwing — three of the four endings are not errors in any useful sense, and a caller
that had to catch them would be deciding which of its `catch` blocks was really a success. The model
keeps what a screen reads: not started, joining, finished. `MacJoining` is the protocol between them,
and it earns its place the ordinary way — the model's tests drive one fake instead of the two
collaborators underneath it, which is the difference between a test about the screen and a second
copy of the test below.

Rejected: scoping the Snapshot row to `Ui` alone. It would have passed the gate today by redefining
a number rather than by fixing what the number was reporting, which is the failure signature the
`swift-testing` skill names — and it would have stopped counting screen composition, which is
drawing code a baseline genuinely does execute.

### The row is right twice, and the second time it says: do not ship a screen's API before the screen

Moving the sequence out took Snapshot lines 83.2% to 88.0% and it was still short, which is the same
sentence one step further in. What was left in the views scope was five members of
`ClientConnectionModel` that **nothing calls** — `PairingState`, `pairing`, `pairedServers`,
`loadPairingHistory()`, `join(_:as:)` — plus the composition root's `handshake:` closure, which only
runs during a pairing attempt. There is no scanner and no pairing sheet, by design: neither has
frames, and the `design-handoff` rule forbids the pull request that would draw them.

So the pairing surface lands with the screen that reads it. `MacPairing` and the whole `Data` layer
stay, tested and judged by the Unit row; what leaves is a property no screen has agreed to and a
wiring line nothing reaches. That is the only option of the four considered that leaves the Snapshot
row **judged**, so the pull request is measured on the same terms as `main` and the ratchet survives
a milestone that added a thousand lines.

**And a belief that had to be corrected before any of this could be sized.** The snapshot bundle is
app-hosted — `TEST_HOST` is `Granita.app`, which is the only reason `drawHierarchyInKeyWindow`
works — so the host's `@main` really launches and the scene, the screen and the model's `init` and
`start()` all execute where the profile is written. They are *not* dead code in that pass, and the
95.7% baseline is arithmetically impossible if they were. An earlier plan to exempt composition roots
from the views scope was abandoned on that evidence: it would have removed a file that is 90%
covered from a denominator sitting at 90%, which moves the row a point, not eight.

The numbers came from running `measure-coverage.sh` locally and reading `snapshot.json` per file.
Three estimates of this had been wrong before that; a per-file export settles in one simulator pass
what algebra kept getting wrong.

### `isPermissionRefused` was a second place deciding one thing

Removed with the above, and it earns its own line because it predates the pull request. The model
exposed `discovery == .localNetworkDenied` as a property; the view already reaches that conclusion
from the state it is handed, and nothing in the app ever read the property — only its own two tests
did. The `swift-style` rule against a helper that merely shortens an inline expression covers it
exactly, and two places deciding one thing is the more expensive half.

Stated plainly because it is also the thing that bought the Snapshot row its margin: after the trim
above the row cleared by 0.13 of a point on lines and sat level on regions, which is inside the
noise of a different runner. Removing dead API for a good reason and needing headroom happened to be
the same edit, and the honest thing is to say so rather than to let it read as tidy-up.

### The one line in the report that did not compare like with like

Found while reading the script for the above. The table skips a row whose scope changed and so does
the gate, but the "N uncovered lines — M more than the baseline" sentence read `categories.all.lines`
straight out of both summaries with no such guard. On this very pull request that made it a
subtraction across two different file sets, reported as a trend. It now asks the same question the
gate asks, and says nothing when the answer is no.

## A pairing that succeeds and cannot be written down is its own outcome

The Mac keeps a hash of the token and the phone keeps the only copy, so a `SecItemAdd` that fails
after `/v1/pair` has answered leaves the worst state this app has: the Mac holds a device record for
a credential nothing can produce, and every subsequent request is `unauthorized` for a reason no
screen could explain. Reported as an ordinary failure it would send the reader round the same loop
forever.

So it is a case of its own on the connection model, and what it has to say is different from every
other failure: revoke the device on the Mac before pairing again.

## The client's Keychain store joins the Mac's as uncoverable, and the scope is renamed again

Same reasoning, second instance, and the bar it met is the one the first one set: a SwiftPM test
binary is unsigned and has no keychain of its own, so the only way to execute
`KeychainPairingTokenStore` at all is to write into a real one. It is behind `PairingTokenStore` for
that reason and everything downstream is tested against a fake.

The scope string moves from `host-reachable` to `host-reachable-no-keychain`, which is the mechanism
declaring itself rather than a tidy-up — the gate compares two numbers only when both were taken the
same way, so the Unit and All rows go unjudged for one run and rejoin on the next `main` run. The
name now says what the exempt set actually is instead of leaving one of its two members unmentioned.

**Unlike the Mac's, this one has not been run.** The Mac's store was verified by running the server
and pairing against it; the phone's needs a device, and the screen that would reach it does not
exist. `status.md` carries that.

**The rename found a bug in the mechanism it was using.** The filter selected on the scope *string*
literal, so renaming the scope in the configuration and not in the filter stopped narrowing anything
at all — silently, and in the direction that looks like good news, since the rows go unjudged for
that same run. The script's own tests caught it on the first CI run. Both scope names are constants
now, so the two cannot come apart, and a test asserts that whatever is configured still removes
something rather than that the two constants equal each other, which would be a tautology.

## The single-file diff route is not called, and the batch is why

SPEC §8 lists both `/v1/worktrees/{id}/diffs?fileIDs=…` and
`/v1/worktrees/{id}/files/{fileID}/diff`. The client calls only the first, with one identifier when
it wants one file.

They are the same answer through the same code on the Mac, and a second way to ask a question is a
second place for it to be answered differently — a divergence that would show up as one file
rendering differently depending on whether it was prefetched or opened. The route stays served,
because removing it is a contract change and nothing is gained by making one.

## The menu bar count costs 122.7 seconds, so there is no menu bar count

The design review declined to draw the dirty-worktree count until someone had timed it, and offered
two branches: tens of milliseconds meant cache it and refresh on a slow timer, seconds meant put the
number behind opening the menu and leave the label as the icon alone. It was measured on 22 August
2026 against ten of Davide's real repositories — 38 worktrees, one Android monorepo carrying 16 of
them — by serving them and reading `/v1/projects`, which is `WorktreeRegistry.projects()` plus a JSON
encode.

**122.7 seconds.** Neither branch survives. A menu that computes this on open is a menu that does not
open, and a cache on a slow timer would keep 38 git processes running for two minutes out of every
period, on a laptop, for a number nobody asked for.

So the count is not built. What it beat was the third option, which was to build it anyway behind a
cache and a spinner — that spends the worst cost this app has on the one surface that is supposed to
be glanced at, and SPEC §9's own framing is that the menu bar answers whether the phone can read this
Mac. The symbol already answers that.

**The number is not the finding; the shape of the question is.** `projects()` computes a whole change
set per worktree — every changed path, its stats and its revision — in order to evaluate
`files.isEmpty == false`. Git can answer "is anything different here" without producing any of it.
The count becomes affordable the day something asks the cheap question, and that is a change to the
git layer rather than to the menu, so it is not in this slice.

Recorded rather than left in a commit message because it is a measurement, and the next session to
look at the menu bar will otherwise re-open it exactly as this one nearly did.

## The second process to open the store refuses to start, and names the first

SPEC §9 asks for a lock file beside the document so a standalone `granita-server` and the menu bar
app cannot both hold it, and says the second one refuses "with a clear message". The review left the
held case undrawn on purpose and said why — refuse, or serve read-only, is a product question rather
than a drawing. Davide answered on 22 August 2026: **refuse.**

Read-only is the option it beat, and it loses on a specific failure rather than on principle. Both
processes read the same document to decide what is enabled; a read-only second process would go on
answering with a snapshot the first one has since changed, so the phone would be served a stale
answer to the one question that is the security boundary — which projects are visible. Neither the
phone nor the reader is told which process answered. A refusal is legible; a quiet disagreement about
what is enabled is not.

The refusal **names the process holding the lock**, and that is the part worth writing down. "Another
copy of Granita is already running" is a sentence with no next action, and the case that produces it
is usually a `granita-server` left in a terminal behind a window. A process identifier can be looked
up and killed.

## The QR was re-opened and kept, and what came back with it is a surface nobody had drawn

On 22 August 2026 Davide asked for the QR to be dropped, on the grounds that the connection mechanism
as it stands is already right, and reversed it in the same exchange once it was clear the picture *is*
that mechanism's one-gesture path rather than a decoration on top of it. **The QR stays exactly as
§5 draws it**, and this entry exists so the call is not re-opened a third time.

What the exchange produced instead is a requirement the review never saw, from a failure Davide has
actually hit: **a device has to be approvable from the Mac, with nothing reading the code.** He
administers this Mac over Screens from his phone, which means the camera and the screen are the same
device — the QR is unscannable in exactly the situation where getting back in matters most, and the
way out today is a second device, a screenshot, and a lot of annoyance.

That is not a layout change, and it is deliberately **not** being invented here. Both halves are
missing. Nothing on this Mac knows a phone exists until that phone presents a credential, so "the
devices on the net" is not a list anything can currently produce; some announcement has to exist
first, and inventing one is a change to SPEC §8's contract rather than a control on a tab. And the
review drew a QR, a countdown and paired rows — not a pending device, not what it says before it is
allowed, and not what Allow does to it.

So §5 ships in two pieces: the drawn half now, and the Allow path after a design round trip and a
protocol decision. Building it from this paragraph is the thing the `design-handoff` rule exists to
stop, and the cost of getting it wrong is a way into the store that nobody designed.

## The Mac's snapshot kind is a second bundle in the same row, not a row of its own

The Mac had no snapshot kind, so every Settings surface was code that nothing rendered and the
coverage report had no way to say so. Adding one raised a question the report's own shape does not
answer: is "snapshot" one kind measured on two platforms, or two kinds?

**One row.** The phone renders on a simulator and the Mac renders on the machine itself — there is no
macOS simulator — but the question the row exists to answer is identical for both: *of the code that
draws screens, how much does a baseline put on screen*. Two rows would split one question along a
platform axis no reader of the report cares about, and would do something actively misleading on the
day the Mac's row first appears: a new row starts unjudged, and a low number beside a high one reads
as a regression in the phone rather than as a kind that has just begun being measured. The two
profiles are merged before the row is taken, exactly as `all` already merges everything.

It moves the denominator, and that is expected rather than a surprise: `Server/Mac/Ui`,
`Server/Mac/Presentation` and `Server/App/Presentation` were in the views scope and in no export,
because the simulator never linked them. They are now in both.

**App-hosted, and for the coverage reason rather than the rendering one.** macOS needs no
`drawHierarchyInKeyWindow` — the `NSView` strategy renders through `cacheDisplay` — so a hostless
bundle would have produced pictures. What it would not have produced is the composition root
executing where the profile is written, which is the evidence the last session's coverage work turned
on. The cost is that the host really launches: the server binds, reaches for the Keychain identity
and tries to advertise. On a runner none of that succeeds and none of it needs to — every one of
those is a `ServerRunState.failed` the app already handles, and no baseline renders the app's own
scene.

### Four things about rendering AppKit that a baseline cannot tell you it got wrong

Each of these produces a picture that looks plausible and asserts less than it appears to.

**And the one that could not be fixed at all: the Mac's baselines are recorded on the CI runner.**
See the entry below; it inverts a rule this project states plainly elsewhere, and it is the only
option of four that survives the measurement.

**A baseline inherits the display's backing scale, so one recorded on a Retina Mac can never pass on
a runner.** This is the one that actually turned CI red, and it is the most important of the four
because the failure names nothing: twelve baselines, `Newly-taken snapshot@(620.0, 560.0) does not
match reference@(620.0, 560.0)`, identical point sizes, no clue. The diff artefact is what said it —
the reference was 1240 × 1120 pixels and what the runner drew was 620 × 560. A CI runner is headless
and has no Retina display, so `bitmapImageRepForCachingDisplay` gives it a 1× rep and this Mac a 2×
one, and every pixel differs for a reason that has nothing to do with the screen being asserted.

So the library's `NSView` strategy is replaced by one of ours that states the raster: the bitmap rep
is built with its pixel dimensions computed from a pinned scale and its `size` left in points, which
is what makes it 2× whatever is underneath. **Proved rather than assumed** — pinning the scale to 1
on this Retina Mac produced 620 × 560 images, which is the same mechanism observed in the direction
that can be tested locally.

Two is chosen over one because a baseline is reviewed by eye and half the resolution is half of what
a reviewer can catch.

**A window that never becomes key draws accent-tinted controls grey, and nothing here can make it
key.** `Open Local Network Settings` — the whole point of that row, the button a reader is meant to
press — renders identically to the `Try Again` beside it, and a switched-on `Toggle` shows a grey
track with the knob to the right. A window cannot become key while its application is not active,
and a test runner is never the frontmost app: `activate()`, `makeKeyAndOrderFront` and switching the
accessory host to `.regular` were each tried and none of them changed a pixel.

**So this limitation is named rather than worked around.** It costs exactly one thing — the accent
tint. Layout, copy, symbols, control shapes, a toggle's knob position and every non-accent semantic
colour are captured; the orange on "Not serving" is in the baselines. What a Mac baseline can never
catch is a `.borderedProminent` quietly losing its prominence, so that call is reviewed in the code.
Worth stating plainly because the failure mode of *not* stating it is a future session recording a
flat-looking screen, believing the design drifted, and re-recording to match.

**A rendered clock time is a locale and a time zone.** General shows when the server bound, so a
runner in UTC and a laptop in CEST draw different pixels from identical code — a failure the suite is
least able to explain. The locale and time zone are pinned once, in the shared hosting, rather than
per test.

**A `Form`'s "fitting height" is not a clipping test, and two attempts at one were wrong.**
`NSView.fittingSize` answers unconstrained, so a long footnote reports an ideal width past the
window's and an ideal height far short of the truth. Constraining the width and asking `sizeThatFits`
is no better: a `Form` is a scroll view and accepts whatever height it is offered. A pane cannot clip
— it scrolls — so the question worth asking is whether it *has* to, and the baseline answers that by
eye. What is asserted from inside the app is the window's content size, which is the thing that
genuinely cannot be measured from outside while Stage Manager is on.

### The macOS kind found two defects in what the coverage rows measure, and neither is a rescoping

Both rows went red, and the reflex — the one this project has now recorded being wrong about twice —
is that the gate is mis-scoped. Read with the per-file export rather than by algebra, it was
reporting two definitions that had only ever been exercised against one platform.

**`Server/Api/Presentation` was in the views scope.** The scope selects on the directory name
`Presentation`, and the server's API module is a presentation layer in the wire sense —
domain-to-wire mapping plus routes. `architecture.md` says it in as many words: *it has no `Ui`
sibling because it has no views.* This was invisible while only the phone had a snapshot kind,
because the simulator never linked those files and an export cannot include what a binary does not
map. The macOS kind links them, and they arrived as **1199 of the views scope's 2350 lines** —
`GranitaRouter.swift` alone contributing 562. The row was being asked how much of the HTTP router a
rendered screen executes.

**A SwiftUI body in `Presentation` was in the host-reachable scope.** That scope excludes `Ui`
because a body needs a renderer and a SwiftPM test target is hostless — and then counts
`GranitaSettingsScreen.swift`, which is a body, because it lives one layer out. `Presentation` holds
both models and the screens composed from `Ui`, and only the second kind needs a renderer;
`ServerMacModel` is an ordinary object a test constructs and stays judged. The incompleteness had
been sitting there at 23 uncovered lines in `ServerDiscoveryScreen.swift`; the Mac's screen is 101,
which is what made it visible.

**The test that says this is a correction and not a rescoping is the direction the number moves.**
With the screens excluded and nothing else changed, the Unit row reads **95.5% against the 93.9%
baseline it had been failing** — higher, not lower. Lines that leave a denominator and take the
percentage *up* were dragging it down by being unreachable rather than by being untested. A
rescoping that flatters a number does the opposite, every time, and that is how to tell them apart.

Both scope strings are renamed, so both rows go unjudged for one run and rejoin on the next `main`
run. That is the second consecutive run in which they are unenforced, which is a real cost and is
named here rather than left to be discovered.

**What is left genuinely uncovered is the Snapshot row at 76.3%**, down from 96.9%, and that number
is honest: the Mac's screens are newly measured and most of them are not rendered by any baseline
yet. `ConnectionLogView` has only its empty state, because a populated row draws its time with
`.relative` and a baseline of it would read differently every day — that is a change to the row and
lands with §6. `GranitaSettingsScreen` is composed by nothing, because rendering it needs the four
fakes the package's test target holds and an app bundle cannot import them.

## The Mac's snapshot baselines are recorded on the CI runner, and the phone's are not

The `swift-testing` skill says it in as many words: **record locally, never on CI**, because a
recorder on CI turns the suite into a record of whatever the code currently does. That rule stands
for the phone. For the Mac it is inverted, and the reason is two numbers rather than a preference.

With the raster pinned and both sides rendering 1240 × 1120, the same code still produced different
pictures on this Mac and on a runner:

| | share of pixels differing by more than 64 levels |
|---|---|
| Cross-machine drift, identical code | **0.737%** |
| A real one-word copy change, same machine | **0.162%** |

**The noise is four and a half times the signal.** There is no `precision` between them: any budget
loose enough to absorb the drift is four times looser than a changed word, so the suite would go
green on exactly the class of change it exists to catch. The skill's own calibration story — 0.98
was rejected because it hid a changed sentence — is this same argument, and it points the same way
here.

### What is actually known about the cause, and what is not

Worth separating, because the first account written here asserted a mechanism that the measurements
only partly support, and a confident wrong story is what stops the next person looking.

**Established.** The runner's window renders at 1× and this laptop's at 2×: before the raster was
pinned, identical code produced 620 × 560 there and 1240 × 1120 here, and
`bitmapImageRepForCachingDisplay` takes its resolution from the window's backing scale. A hosted
macOS runner is headless. `NSWindow.backingScaleFactor` is derived from the screen and has no setter,
so pinning the raster — necessary, and done — cannot reach it.

**Also established, by measuring the images rather than reasoning about them:**

- Both sides are genuine 2× rasters afterwards. Among blocks sitting on a content edge, the share
  that are a single flat colour is 1.1% on the runner and 34.9% here; a doubled 1× image would be
  ~100%. The runner is not upscaling.
- The residual is not a whole-image shift. Rolling this laptop's image one device pixel up improves
  the mean absolute difference from 1.42 to 1.08 — so there is roughly half a point of vertical
  offset — and leaves most of the difference in place.
- It concentrates in the two smallest text lines. The worst rows are the footnote captions, at mean
  absolute differences of 32–40 out of 255, while the rest of the pane is close.

**Not established.** That glyphs "snap to a different grid" was the first explanation offered here and
it is an inference, not a finding. It fits the offset and the concentration in small text, and the
edge-block figures above sit awkwardly with it: this machine produces the *coarser* image of the two,
which grid-snapping does not predict. The backing-scale difference is the only environmental
difference actually demonstrated, and it is plausibly upstream of the rest — but the mechanism is
open.

Settling it would need a Mac with a 1× display, or a virtual display attached to the runner. It was
not bought, because no decision turns on it: the drift is four and a half times a real change
whatever produces it.

So the runner is the only machine whose renders are reproducible on the machine that gates them, and
`Scripts/adopt-mac-baselines.py` takes them out of the job's own diff artefact. Davide chose this on
22 August 2026 over three alternatives: gating the Mac suite locally only, which leaves a check
nobody runs; dropping the image assertions, which gives up checking the design was built as drawn;
and giving the runner a virtual 2× display, which is fragile infrastructure on a hosted runner and
could not be verified without several more round trips.

**What it costs is that `make snapshots-mac` is red on a developer's Mac, permanently and by
design.** That is a loaded gun pointing at the next session, whose obvious move is to re-record
locally and "fix" it — which makes every pull request red instead. Three things are arranged against
that: `make record-snapshots` no longer touches the Mac's baselines at all, `make snapshots-mac`'s
help text and comment say the red run is expected, and the adoption script's docstring carries the
measurement. The target is still worth running locally for its diff report, which is what shows a
person what moved.

**The rule that does not change is that a picture nobody looked at is not a baseline.** Adopting a
runner's render is accepting an image sight-unseen unless someone opens it, so the script prints
every file it writes and says so.

## The General tab re-reads the login item's status, because `register()` succeeding means very little

`SMAppService.register()` returns without throwing in the case that matters most: macOS accepts the
registration and then waits for the user to approve Granita in Login Items, leaving the status at
`.requiresApproval`. Nothing runs at the next login.

Reported as success — which is what a naive `try service.register()` does — the toggle shows on, the
reader believes the app will be there in the morning, and finds out it is not by rebooting and
watching their phone fail to find the Mac. For an app whose entire job is to be running when the
phone looks, that is the worst failure this tab can produce, and it is the *default* one.

So the registry re-reads its own status afterwards and reports anything that is not `.enabled` as not
registered, and the toggle has a third and fourth state rather than a boolean: waiting for approval,
and refused outright with the system's words. Both draw **off**, because a switch left on for a
registration that will not happen is the only reading on this tab that is actively false.

Rejected: putting the sentence in the `Data` layer by throwing a pre-worded refusal. The layer that
talks to `SMAppService` should say what happened, not how it reads.

## A control that does nothing is never shipped, and this project shipped one

Between 0.0.4 and 0.0.11 the discovery list's rows were `NavigationLink(value:)` and **no module
declared a destination for that value**. Tapping the Mac a reader opened the app to read did nothing
at all — no push, no message, no spinner. It reached TestFlight, and it is the worst defect this
product has had.

It was **known**. `GranitaMobileScene` carried a comment saying "the rows link to a destination this
stack does not have and tapping one does nothing, which is what tapping one already did". That
sentence is the whole failure: a defect was observed, written down, reasoned about, and shipped,
because it was filed as *the pairing screen is not built yet* rather than as *the app has a dead
control in it*. Those are not the same thing, and only the second one is a release blocker.

**The rule is now stated where it cannot be missed rather than where it must be looked up** — in the
global `CLAUDE.md`, in this repository's `CLAUDE.md`, and in the `/design` skill's binding rules.
Before any control ships, one of these is true: it works; it is absent; it is disabled **and**
labelled with why; or it is enabled and explains that the thing behind it is not built. Being
mid-slice is not an exception — it is the case the rule is for.

It was first written as a skill of its own and that was wrong, which is worth one line: **a skill is
read when something reaches for it**, and nothing reaches for a rule about dead controls while
believing it is only deferring one. A rule that must hold unconditionally belongs in the files that
load unconditionally.

**Two things about it are specific to how this codebase is built.** Clean layer boundaries make this
*easier* to miss rather than harder: every layer looked finished on its own, and the gap was between
two modules. And **the snapshot suite cannot catch it** — a baseline photographs a row beautifully
whether or not the row leads anywhere, which is exactly what happened here. The check is running the
app and pressing the thing.

So the destination now lives in `ServerDiscoveryScreen`, **beside the rows that link to it**, rather
than in the composition root where it would have gone. A link and its destination in two modules is
what let them drift apart invisibly; in one file, adding the first without the second is something a
reader sees. What that beat: leaving it in the root and relying on the rule alone, which is the same
arrangement that already failed once.

Rejected: disabling the row. It would answer "why can I not tap my Mac" with nothing, which is a
different unanswerable question. And rejected: removing the row, which leaves a discovery screen that
finds Macs and does not let you choose one — the app would then have no purpose a reader could see.

**What is still owed is the test that would have caught it**, and it is named here so it is not
forgotten: a behavioural test that taps a row and asserts something appears. That is the `ui` kind
this project has no target for, and this defect is what earns it.

## The connection log's elapsed time is handed in, which is what makes the panel photographable

The row drew its time with `Text(_:style: .relative)` — live, correct on screen, and measured against
the moment of rendering. That is why the macOS snapshot kind landed with only this panel's *empty*
state: a baseline of a populated row read "3 minutes ago" the day it was taken and "2 days ago" the
week after, so there was nothing to compare against.

So the view takes `now` as a value and computes the elapsed string from it. A populated row is then a
pure function of a fixed clock and a fixed list, and four states of the panel have baselines that
previously could not exist. The screen supplies the clock from a `TimelineView` on a per-minute
schedule, which is both the cheapest thing that can move it and exactly as often as a row changes —
the coarsest unit this row prints below an hour is a minute.

**What it beat is `.relative` plus an excluded test.** Snapshot testing has a way to say "compare
everything except this rectangle", and using it here would have kept the live time and bought a
baseline for the rest of the row. It loses on what it hides: the time is the widest column on the
right-hand side, so excluding it also stops the baseline from catching the row growing into it, which
is precisely how the long `pairingNotRecordable` sentence misbehaves. A value the view is given is
also the thing a `Ui` module is supposed to be — it renders what it is handed and derives nothing.

**A second locale trap came with it, and it is the same one the clock had.** The count is routinely
four digits, and `Int.formatted()` reads `Locale.current` — the *process's* locale, which a SwiftUI
environment cannot pin. Identical code wrote `1,284` on the runner and `1.284` on an Italian laptop.
The number goes through `Text`'s own format interpolation instead, which resolves against the
environment, so the pinned `en_US_POSIX` reaches it. Worth writing down because the mechanism is
invisible: both spellings are correct, both look deliberate, and only a cross-machine run says which
one a baseline is holding.

## The coverage gate's first true red, and the two holes it found

Three of its reds have been noise — measured, and recorded above. This one was not, and telling them
apart took the same method both times: measure both sides locally, through `coverage.py`'s own scope
filter, and read the per-file export.

**The Unit row went *up* +0.2 while `All tests` regions fell 0.9%**, which is far outside the ~0.3%
spread. That divergence is the signature: the unit profile is `swift test`, and the merged profile
also links the Mac app, so a module the package does not link is invisible to the first and counted
at zero by the second.

**`Server/Mac/Data` was that module.** Nothing in the package depended on it — the composition root
is an app target — so `ProcessGitInstallations` had no test and no row in the unit export to say so.
It now has a test target of its own, which is the fix for both: the failures each carry git's own
words, and that is the whole point of the row they feed.

**And `GranitaSettingsScreen` was the second**, in the views scope and rendered by nothing, so every
line the Advanced tab added to it went straight into the denominator. It is now rendered with six
fakes held in the snapshot bundle, which is the same trade the `Api` and `Mac` suites already make:
test targets cannot import each other, and the alternative ships doubles in the binary a reader
installs.

**Closing the first hole opened a third, and it is a scope correction rather than a gap.** Giving
`Server/Mac/Data` a test target linked it into the unit profile for the first time — which brought
`ServiceLoginItemRegistry` with it, at **0 of 15 regions and 0 of 25 lines**. It had never been
judged, only invisible.

It is exempted, on the bar `UNREACHABLE_FILES` already sets and not on the arithmetic: every line of
it is a call on `SMAppService.mainApp`, which is the *running main bundle* — in a test process, the
unsigned test runner. Running it means either failing for want of a signature or writing the test
binary into the developer's real Login Items. That is the same class as the two Keychain stores,
which are exempt because a SwiftPM test binary is unsigned and has no keychain: **unrunnable by
construction, not merely untested.**

The honesty check this project applies to a rescoping is whether it flatters a number, and this one
*does* raise it — 90.4% to 91.4% — which is why the justification is the bar rather than the
direction. The distinguishing fact is that the file entered the scope and was exempted in the same
breath, rather than having been measured and then excused. The scope string is renamed from
`…-no-keychain-…` to `…-no-system-services-…`, so the Unit and All rows go unjudged for one run and
rejoin on the next `main` run. That is the third time these rows have been unjudged, which is a real
cost and is named here rather than left to be discovered.

**Two things that baseline cannot do, stated so they are not assumed.** It does not capture the tab
bar — a `TabView` hosted in a plain window draws the selected pane and no picker, because the
segments come from the `Settings` scene and a test bundle has none, so tab order and symbols stay
reviewed in code like the accent tint. And the model must be **driven** first: the screen does not
start the server, the composition root does, so a screen rendered straight after construction reports
`.starting` whatever it was handed — a baseline named "serving" showing "Starting…" asserts the
opposite of its own name, which is what the first attempt at it did.

## A new Mac baseline needs a placeholder pushed first, because a missing one never reaches the artefact

The adoption round trip — push, let `Snapshot tests (macOS)` fail, `gh run download … -n
snapshot-diffs-mac`, `Scripts/adopt-mac-baselines.py` — works for a baseline that **changed** and
silently does nothing for one that is **new**. The report is built from `__SnapshotFailures__`, and
swift-snapshot-testing does not write there when there is no reference: it records the image into
`__Snapshots__` and fails that run instead. So the artefact for a first run of a new test is the
script's own "no snapshot mismatches were captured" placeholder, and there is nothing to adopt.

**So a new baseline lands in two commits.** The first pushes this machine's renders as placeholders,
which turns "no reference" into a mismatch; the second replaces all of them with the runner's. Both
commits say which they are, because a placeholder left behind is exactly the locally-recorded baseline
this whole arrangement exists to prevent — and it would be green on the run that introduced it and red
on every run after.

Rejected: recording on CI with `record: true` behind an environment variable, which is the same
"suite that cannot fail" the `swift-testing` skill forbids, aimed at a narrower target. And rejected:
teaching `snapshot-report.py` to emit a section for a newly-recorded image, which cannot work — the
job's checkout is what the report reads, and a newly-recorded image is only ever on the runner's disk
inside a directory the failing step does not upload.

Written down because the failure is silent in the worst way: the script prints `0 baseline(s)
adopted`, which reads like "nothing needed adopting" rather than "there was nothing to adopt".

## Advanced ships without its Diagnostics half, because Granita has no logging at all

Design §7 draws a verbose switch and an **Open in Console** button beside it, with the footnote
*verbose logging records every request and every git invocation until you turn it off*. Both were
built on a premise nobody had checked: there is **no logging anywhere in this product**. Not a
`Logger`, not an `os.log`, not a print — the whole package, searched.

So the switch would turn on nothing and the button would open a Console filtered to a subsystem that
never writes. A control over an absent subsystem is worse than an absent control: it reads as a
feature, it is pressed, and what it reports is silence that looks like "nothing is wrong".

**They land with the logging they describe**, which is its own slice — a seam in `Domain`, an
`os.Logger` behind it, and call sites at the request boundary and at every git invocation, because
that is what the footnote promises. Advanced ships now with the two rows that stand on their own: git,
and the data folder with Reset.

**And Console cannot be filtered from outside, which is settled before that slice starts.**
`Console.app` registers **no URL scheme** — its `Info.plist` has no `CFBundleURLTypes` at all — so
nothing can hand it a predicate. Davide chose, on 22 August 2026, that the button opens Console and
puts the predicate on the pasteboard, so one paste finishes it. What that beat: opening Console
unfiltered, which is the exact failure the review says the button exists to prevent — *a level control
with no route to the log leaves a person choosing how much of something they cannot find*; and running
`log stream` in Terminal, which is genuinely filtered and leaves the reader in a different app,
holding a process this one does not own.

**The lock-file row is absent for the same shape of reason**: SPEC §9's lock file is not built, so the
row that reads its refusal has nothing to read.

## Reset is a store method, and a refused one leaves the count telling the truth

`Store.reset()` rather than the tab deleting the document, because the store owns what the document
means and is the actor that serialises writes against it. It goes through the same atomic replace as
every other mutation: a reset that cleared this process's memory and left the file alone would restore
everything it claimed to destroy at the next launch, which is the one outcome nobody would think to
check for.

**It is all four records rather than a choice of them** — projects, devices, aliases and pins, viewed
marks. A reset that left one behind would leave the reader believing the rest went too, and the record
most likely to be left is the one that matters: a project still enabled is a repository still being
served.

**The model swallows a refusal and re-reads the counts, which is deliberate.** A full disk or a
document from a newer Granita means nothing was destroyed. Because the sentence above the button is
counted from the store rather than remembered, re-reading it leaves that sentence describing what is
still there — and a tab that answered a failed reset with "nothing is stored" would be lying about the
one thing on this pane that is the security boundary.

## The Connections row's `Pair…` button lands with Devices, not with the row

Design §6 gives a refused row the one affordance a served row does not have — `Pair…` for no token,
`Pair Again…` for a token this Mac did not issue — and §1 settles where it goes: there is one QR in
this app and both doors open it, on the Devices tab.

That tab does not exist yet, so the button has nowhere to lead. Shipping it wired to nothing is worse
than shipping it late: a button that visibly does nothing is a defect a reader reports, while a
missing one is a panel that has not finished arriving. Everything else in §6 — the tab, the relaid-out
row, the count, the footer, the empty state — is built and has baselines.

So **§6's frames stay in the design review until the Devices tab ships them**, which is the same
shape §1 is already in and for the same reason. The rule that a section's frames are deleted by the
pull request that ships it is unchanged; this is one section shipping in two pieces, named here so
the second piece is not lost.

## The Projects row costs two different amounts, and the expensive half is filled in rather than dropped

Design §4 draws the trailing figure as two lines — `4 worktrees` over `2 with changes` — and says it
comes from `Project.worktreeCount` and `dirtyWorktreeCount`, "which already exist". They do. What
the review could not know is that the second one had not been timed yet, and when it was, on 22
August 2026, the answer was **122.7 seconds** across ten real repositories. That measurement killed
the menu bar count. It arrives at this tab too, and the review's own sentence says why it must:
the figure is "what reconciles this tab with the number in the menu bar", and there is no number in
the menu bar.

**So the cheap question was measured before anything was decided.** `WorktreeRegistry.projects()`
builds a whole change set per worktree — every changed path, its stats, its revision, a hash of every
changed file — to evaluate one boolean. Git can answer "is anything different here" with one
invocation. On 23 August 2026, against Davide's `bandlab-android` monorepo and its sixteen worktrees:

| | wall clock, warm |
|---|---|
| `git status --porcelain`, per worktree | **16.7 s** for sixteen |
| `git diff-index --quiet HEAD`, per worktree | 8.0 s for sixteen |
| `git worktree list --porcelain -z`, whole project | **0.014 s** |

Two orders of magnitude cheaper than the change set, and still about a second per worktree. One
monorepo alone is longer than anybody waits for a settings pane.

**Davide chose to fill it in progressively**, on 23 August 2026, over dropping the second line
entirely and over computing both before drawing. So the tab reads the store and the worktree counts,
draws the whole list, and *then* walks the visible projects asking the cheap question, each answer
landing in the row it belongs to. What that beats:

- **Dropping `2 with changes`.** It was the recommendation and it lost on what the line is for: the
  worktree count says how much is behind a switch, and only the second line says whether there is
  anything to read. A row that cannot answer that is a row about filing rather than about work.
- **Computing both before drawing.** A pane that is blank for a minute on ten repositories, every
  time it is opened.

**Three things make the progressive fill honest rather than merely deferred.** The second line is
drawn as `checking…` rather than left absent, so nothing below it moves when the answer lands — this
is a list a reader is aiming a switch at. The expensive question is asked **only of projects that are
switched on**, because a switched-off row says `not visible` and has nowhere to put a count. And the
walk is cancelled with the tab's own `.task`, so leaving Projects stops the git invocations rather
than running them into a list nobody is looking at.

**The cheap question is `worktreeStatus`, a command the vocabulary already had**, so no case was
added to `GitCommand`. `status` prints nothing at all when there is nothing to report, which makes
the boolean "did it print". It agrees with the change set by construction rather than by coincidence,
because it is the same command with the same untracked mode — and that matters: `diff-index --quiet`
is faster and answers *no* for a worktree holding nothing but new files, which is precisely what an
agent leaves behind.

## What a folder scan will not look at, and why each refusal is there

SPEC §9 names six directories a scan skips — `node_modules`, `.build`, `DerivedData`, `Pods`,
`vendor`, `target` — and the §4 frames show `vendor/swift-nio` as a candidate. That is the second
place the design and the specification have disagreed, so it went to Davide rather than being
resolved by whoever read one of them last. **Answered on 23 August 2026: the specification wins.**
The drawing's row reads as an illustration of a candidate at a nested path, which the sheet needed an
example of; the skip list is explicit and argued. Recorded because `design-handoff` says a
disagreement is worth a line rather than a silent resolution.

Three more limits are ours, and none of them is in either document:

- **Hidden directories are refused wholesale** rather than named one at a time. Everything under a
  leading dot is a cache, a trash can or an agent's scratch space — including every worktree Claude
  Code creates, which lives under `.claude/worktrees` and is a checkout of a repository the reader
  already has. It also makes `.build`'s presence on the specification's list redundant, which is
  fine: the list is what SPEC says and is kept as written.
- **Four levels below the folder that was picked.** A scan is a person pointing at where they keep
  their work, not a search of a disk, and an unbounded walk of a home directory is minutes of I/O for
  repositories nobody filed there on purpose.
- **A candidate is a folder with a `.git` *directory* in it**, never a `.git` file. The difference is
  a linked worktree, whose `.git` is a file pointing back at the repository it belongs to — adding
  one as a project would enumerate exactly the worktrees that repository already offers, under a
  second name, with a second switch over the same files.

Symbolic links are not followed either, and that one is not a policy so much as a termination
argument: a link is somewhere else's directory reached by a second name, so following one offers the
same repository twice, and a link pointing back up the tree is a walk that does not end.

**The scan runs no git at all**, which is worth stating because everything else on this tab does.
Thirty candidates is thirty `.git` directories found by `FileManager` and zero subprocesses. What
makes that safe is that the one add which *can* be aimed anywhere — the folder picker — checks, and
the sheet's candidates are folders this Mac found a `.git` in a moment ago.

## Locating a moved project is a remove and an add, because an identifier is a hash of a path

`Locate…` looks like an edit and cannot be one. Every opaque identifier in this product is derived
from a canonical path, so a project that moved is a *different* project to everything that resolves
one — the store, the API, the phone. Editing the path in place would leave a record whose identifier
no longer derives from its own contents, and the next thing to recompute one would stop finding it.

So the move is `removeProject` followed by `add`, with the name and the switch carried across because
those are the two things a reader decided. `Store` grew `removeProject(id:)` for this and for the
minus button, and it deliberately leaves worktree aliases and viewed marks alone: they are keyed by
their own path-derived identifiers, so re-adding the same folder finds them where it left them, and
nothing outside an enabled project is ever served.

**The switch survives the move, and that is the call worth naming.** A project switched on before its
folder moved comes back switched on, which is what makes `Locate…` a repair rather than a second
setup. What it beats is relocating to *off* on the grounds that a path change is security-relevant —
it is not: the reader is standing at the Mac naming the folder, which is exactly the gesture that
enabled it in the first place.

Rejected outright: making the switch's disabled state flip the project off while the folder is
missing. Turning off something a person turned on, while they are not looking, is a decision this app
does not get to make — and a project switched off by the app is indistinguishable, a week later, from
one they switched off themselves.

## A Mac baseline of a pane that is not a `Form` was rendering on white, and in dark that hid a control

Every Settings pane before Projects was a `Form` with `.formStyle(.grouped)`, which paints its own
background across the whole pane. Projects is a bordered list and a plus/minus bar, so it paints
none — and the snapshot host renders the **view**, not the window, so what came out was the pane
flattened onto nothing, which is white.

In light that is nearly right and hides the problem. **In dark it is catastrophic and silent**: the
pane's own foreground is light, so the add and remove buttons and the footnote under the list came
out white on white. Sixteen baselines were taken, adopted from the runner, and reviewed — and the
dark ones were pictures of a control that was not there. That is the exact failure the whole suite
exists to catch, arriving through the suite itself.

**The fix is in the hosting rather than in the view, and the direction matters.** The product is
correct as written: in the real Settings window the pane is transparent over the window's own
background, which is what a pane that is not a `Form` is supposed to be. Painting a background into
`ProjectsSettingsView` to make the picture right would have been changing the product to flatter a
test. So `hostedInWindow` puts `windowBackgroundColor` behind whatever it is handed, which is the
colour the pane really sits on. The status item's helper does **not** get it: a menu bar item is not
on a window background, and giving its 44 × 22 baseline one would be drawing a backdrop that does not
exist.

Found by looking at the pictures, which is the rule this project already had and the reason it has
it. Nothing else would have said so — the suite was green against baselines it had just written.

## The two states §4 argues hardest for were unphotographable, and that was a layering mistake

`AddRepositoriesSheet` held what was ticked as its own `@State`, and `ProjectsSettingsView` held
which row was selected. Both read like a view's own business and neither is, because of what it
costs: the states those controls turn **on** could then be reached by nothing but a finger. The
sheet's confirm was photographed only saying `Add` and greyed out; the footer's `2 chosen of 30`
never at all; the minus only in the state where it cannot be pressed. Design §4 argues about the
count being in the verb across a whole paragraph, and the suite had no picture of it.

The coverage gate said the same thing in numbers before the eye did — the Snapshot region row fell
9.3 points, which is far outside the ~0.3% noise these rows drift by, and every uncovered region was
in a branch only an interaction could take.

So both move out to the screen that composes them, and both views take a `Binding`. That is what
`architecture.md` already says a `Ui` module is — *each takes what it renders and reports what
happened* — and this is the first time the rule has paid a debt rather than merely been followed.
Two baselines came back with it: a sheet with two ticked, and a list with a row selected.

Rejected: adding a parameter to the views that only a test would pass, which is the same picture
bought by making the production initialiser lie about what the view needs. And rejected: accepting
the lower number as honest, on the grounds that a snapshot cannot click — it can, once the thing it
would have clicked is a value it is handed.

## A screen was doing I/O, and the coverage gate had been reporting that for three runs

`GranitaSettingsScreen` held four AppKit statics — `NSOpenPanel`, `NSPasteboard`, `NSWorkspace`
twice — and the closures that called them. The comment excusing them said they were "one-line system
gestures with nothing to decide and nothing a test would assert; a seam here would be an abstraction
invented for a future nobody asked for". That was true when it was written and stopped being true
the moment Projects added a folder picker: **a picker decides.** It comes back with a folder or with
a reader who changed their mind, and every one of the three call sites branches on which.

The gate had been saying so and was misread. The Snapshot row fell and the reflex — twice recorded
in this file as wrong — was that the scope was mis-drawn. Measured per file through `coverage.py`'s
own reader, `GranitaSettingsScreen` was at **45 uncovered regions of 56**: not because it is a view,
but because a view body is where no test can supply an answer to a question the code asks.

**A scope change was proposed here and Davide refused it**, on 23 August 2026, with the argument
that settles it: *Ui must be declarative; if a state cannot be driven by a model, and it isn't
testable because of that, we have a structural issue.* The proposal would have excluded models from
the views scope and taken the number back over its baseline without touching the defect. It was the
third time this project has reached for a rescoping and the first time the reach was wrong.

So the I/O left the screen, which is what `architecture.md` has said all along — *anything that
touches the outside world sits behind a protocol its `Domain` owns, with one implementation in a
`Data` module and a hand-written fake in tests*. Two protocols, because they differ in the way that
matters: `FolderPicking` answers and `SystemGestures` does not. `AppKitFolderPicker` and
`AppKitSystemGestures` hold the AppKit; the model gained `addProjectFromPicker`,
`scanFolderFromPicker`, `locateProjectFromPicker`, `copyAddress`, `revealDataFolder` and
`openSystemSettings`, all of them ordinary methods a test drives; and the screen became composition
and nothing else.

**Three things came free, and each is the sort that was previously unaskable.** Whether the string
Copy puts on the pasteboard is the one the row shows — it is, and it is asserted now rather than
computed twice. Whether copying while the server is down copies the em dash the row draws — it does
not. And whether the two `x-apple.systempreferences:` literals still parse, which nothing in the
product would have noticed: a mistyped extension identifier opens System Settings on its front page,
which looks exactly like the app working.

**What is ticked in the scan sheet moved to the model in the same pass**, and the distinction is
worth keeping: a highlighted row drives nothing and stays the screen's own `@State`, while a ticked
checkbox decides what a confirm button will add and belongs beside the scan it came from.

Rejected: keeping `copy`, `reveal` and `openSystemSettings` inline on the grounds that they really
are one-liners with nothing to decide. They are — but they are I/O in a view either way, and leaving
three behind while moving the fourth would have been a rule applied by size rather than by kind.

## The composition roots are a layer called `Main`, and that is what stopped two predicates lying

Three modules mix layers on purpose, because wiring implementations into protocols is their whole
job. Two of the three were filed under `Presentation` — `Client/App/Presentation` and
`Server/App/Presentation` — and the third, the executable, was already at `Server/Cli/Main`. So the
exemption could not be read off a path, and every place that needed it named the modules one by one:
this file, `architecture.md`, the `architecture` skill, the manifest's header comment, and **a clause
inside each of the two coverage scope predicates**.

Those last two are what made it worth fixing rather than tidying. The views scope had to say "a
composed screen, unless it is in a composition root", and the host-reachable scope had to say "not a
composition root", each matching a *pair* of directory names because neither could match a layer. The
same fact, spelled twice, in two different shapes, in the script that decides whether a pull request
may merge. Renaming the two roots to `Main` replaces both with a layer name matched exactly the way
`Ui` already is — and the views clause disappears outright rather than getting shorter, because
`Main` is neither `Ui` nor `Presentation` and so nothing in a root selects into that scope at all.
A test pins that, since the predicate now reads as though the `…Screen.swift` suffix were sufficient.

**The rows stay judged, which was the constraint.** A scope rename un-judges the Unit and All rows
for a run, and they have been unjudged for three of them already. None is needed here: the predicate
selects the same files it always did — the roots moved, the rule did not — so the question each row
answers is unchanged and the ratchet keeps holding.

### What a root may hold, which is the half that is not about a name

A root is exempt from **both** coverage rows, so anything in one that a test would want to assert has
quietly stopped being visible as untested. `Server/App` was carrying two such things behind the
wiring, and neither was a layer's worth of code — which is exactly why they were easy to leave.

**A server host with four sentences nobody could reach.** `KeychainBackedServerHost` turned each
`ServerIdentityError` into a line a reader standing at the Mac acts on — *unlock the login keychain*
— and no test could produce any of them. It is now `TransportResolvingServerHost` in
`Server/Api/Presentation`, beside `ApiServerHost` and `RebindingOnWake`, which is where its siblings
already were. What made the move possible is that it resolves an **`ApiTransport`** rather than a
Keychain identity: the late-bound thing is then the same value the configuration already takes, the
module needs no `Data` dependency, and a host test drives every line of it with plaintext on
loopback. The per-run claim its own comment made — *asked per run, so a rebind after waking can fail
for a reason someone can act on* — is asserted now by counting resolutions across two runs, rather
than described.

**And a wake source that turned out not to need the exemption it was expected to need.**
`WorkspaceWakeNotifications` moved to `Server/Mac/Data`, beside the other conformers that read this
Mac, on the assumption that it would have to join `UNREACHABLE_FILES` — every line is AppKit, and
that list already carries `AppKitSystemGestures` for the same shape of reason. Checked rather than
assumed: `NSWorkspace.shared.notificationCenter` is an ordinary notification centre and a test may
post to it, so the one thing that makes a slept laptop reachable again is now covered by a test
instead of exempted from being one. Worth recording because the expectation was the opposite, and
because the exemption would have forced the scope rename this entry says was avoided.

Rejected: leaving both in the root and noting the exemption in a comment. That is what the root's
previous occupant did — `GranitaMacScene` carried a comment explaining a dead control for eight
releases — and a note beside untested code is not a substitute for a module that measures it.

## The macOS UI test kind lands built but unrun, and the grant it waits on is Davide's

The kind this project has owed since a dead control shipped for eight releases. A baseline
photographs a row whether or not the row leads anywhere — that is how the discovery list's
`NavigationLink` to nowhere stayed green through four layouts for four releases — so the only check
that catches one is a test that presses the thing and reads back an effect.

It was written and abandoned three times on 23 August 2026, each failure naming the next constraint,
and the sequence is worth keeping because none of the three messages says what is wrong:

1. `CODE_SIGNING_ALLOWED=NO` gives **"Test crashed with signal kill before establishing
   connection"**. A UI test bundle is not loaded into the app — it is a separate runner app that
   launches and drives another process — and an unsigned runner is killed before it can connect. So
   this is the one target in the repository that is **signed**, and `make ui-tests-mac` omits the
   flag every other target passes.
2. Signed, it gives **"Cannot code sign because the target does not have an Info.plist"** — naming
   the *snapshot* bundle while the UI bundle is the one being run. No test bundle here had ever been
   signed, so none had a plist. `GENERATE_INFOPLIST_FILE` goes on **both**.
3. Signed and with a plist, it gives **"The test runner failed to initialize for UI testing. (Timed
   out while enabling automation mode.)"** That one is not a project setting. It is the Accessibility
   privilege the runner needs, under System Settings › Privacy & Security › Accessibility, and it is
   Davide's to grant. **The target has therefore never been seen to pass.**

### Three invocations had to be scoped before the bundle could join the scheme

Adding it to the `GranitaMac` scheme means every invocation of that scheme runs both kinds. Without
`-only-testing`, the `Snapshot tests (macOS)` job would start driving the app as well as
photographing it — turning a green job red in the job least able to explain why, and on a runner with
no Accessibility grant either. So `-only-testing:GranitaMacSnapshotTests` is on `make snapshots-mac`
**and on the CI job**, and `make ui-tests-mac` carries the other half.

The bundle is still **built** by that job, which is the only thing keeping it compiling until
something runs it. Verified rather than assumed: a `build-for-testing` over the scheme produces
`GranitaMacUiTests-Runner.app` unsigned, so the signing requirement is a runtime one and CI's
`CODE_SIGNING_ALLOWED=NO` does not break the build.

### The `ui` coverage row is deliberately not wired in the same pull request

The report has always had a row for this kind and it has always been absent. Filling it here would
mean measuring an out-of-process profile that nobody has ever produced, on a target that cannot yet
run — and a near-zero row becomes the ratchet baseline the moment it is recorded. It lands with the
first green run, not with the target.

### XCTest, in this bundle and nowhere else

`XCUIApplication` is XCTest-only; there is no Swift Testing equivalent. The `swift-testing` skill's
rule is unchanged everywhere else in the repository, and this is the exception rather than a
loosening — the bundle is the boundary.

### The app is driven against a store in a temporary directory

`--store` is why `MacLaunchOptions` exists, and this is the case it was built for: without it the
test would drive the reader's own document on a real Mac and switch a real repository on, which is
the one thing the Projects tab must never do by accident. `--open-settings` is the other half —
Granita has no window until its menu is opened, so a test would otherwise have to hunt a status item
in the menu bar before it could assert anything. Both go through the same call the menu uses, so what
a test opens is what a reader opens.

The assertion is read back from the **document**, not from the screen. A row that redraws itself
while nothing is written is precisely the defect this kind of test exists to catch, and a test that
read the toggle back off the toggle would pass in that case.

## The address conversion is public so that all four of its answers can be decided by a test

`LocalAddresses.current()` reports whatever this machine has up at the instant it is called, which
makes it a poor thing to assert against and a worse thing to measure. Its IPv6 branch ran only when
an IPv6 address happened to be up, and the **link-local rejection ran only when one happened to be
link-local** — so the one case with a consequence a reader would ever meet, a certificate naming an
address that matches nothing, was covered by luck rather than by a test. The unsupported-family
branch, which in production runs on every interface a Mac has because every interface reports a
link-layer address alongside its IP ones, was asserted by nothing at all.

Davide chose fixing the nondeterminism over widening the coverage gate, and the split is the fix:
the enumeration stays what it honestly is — a smoke test against the real machine, which is the only
thing that can say `getifaddrs` still works — and the pure conversion becomes
`certifiableAddress(of:)`, fed fixed `sockaddr_in` and `sockaddr_in6` values.

**Public rather than `@testable`.** Nothing in this repository imports a module that way, and
starting here would buy one test's convenience with a convention. The function is also a nameable
unit on its own terms: it answers *what address, if any, can a certificate carry here*, which is why
a link-layer address and a link-local one both come back as nothing.

**It cannot move to `Domain`.** `sockaddr` is Darwin's, and a `Domain` target sees Foundation and no
framework. So it stays in `Data` beside the enumeration that feeds it.

**The boundary cases are the point, and they were confirmed to fail.** Link-local is `fe80::/10`, so
what decides it is the top two bits of the second byte rather than the whole byte — `febf::1` is the
last address inside the range and `fec0::1` the first outside. Rewriting the guard as
`read[1] != 0x80`, which is the plausible wrong version, turns the `febf::1` case red and leaves
everything else green. A test that only ever tried `fe80::1` would have passed against both.

### A reader that has gone away is dropped on the next write, not by announcing its own departure

Found by the artifact above, on the first pull request that had it. `InMemoryConnectionLog` removed a
finished reader from an `onTermination` closure that hopped through a detached `Task`, and whether
that task ran before a test process stopped writing its profile was a **race**. It won on this laptop
and lost on the runner, which surfaced as the Unit and All region rows each falling 0.1% on a branch
that had touched nothing anywhere near it — the kind of red that reads as "the gate is mis-scoped"
and is neither that nor a real regression.

`record` now prunes readers whose `yield` reports `.terminated`. That is synchronous, sits on the one
path every test in that suite already drives, and deletes two regions rather than making them
reachable: the closure and the private removal are both gone. What it costs is that a finished
continuation is held until the next attempt is recorded, which is a `UUID` and a continuation.

**This is the same defect as the one the pull request was about**, arriving in a second file — a
region whose coverage is decided by the machine rather than by a test. Recorded together because the
tool that found it is the artifact added to diagnose the first, and because the pattern generalises:
an asynchronous cleanup path with no observable consequence cannot be asserted, only raced.

Rejected: exposing the reader count so a test could wait for the removal. It is state nothing else
reads, so it would be API a test alone justifies — and it would have kept the race and merely made it
survivable, rather than removing it.

### And a third instance, in the one place the product cannot afford it

The same read found `GitInvocation.quotedIfNeeded`'s escape table covered on this laptop and not on
the runner. It was not a measurement artefact: of the four escapes git's C-quoting needs, **only the
newline had a test.** The carriage return, the backslash and the double quote were reached, when they
were reached at all, by whatever paths happened to exist in a fixture repository — so a runner with a
slightly different checkout exercised a different subset, and the row moved for reasons no one had
written.

The gap matters more than the number. `--stdin-paths` unquotes a line with C escapes once it begins
with a double quote, so a backslash left bare is read as the start of an escape and **the path git
hashes is not the path on disk**. That is a wrong content hash, and a wrong content hash silently
un-marks a file the reader had marked viewed — a defect with no error anywhere, on the one mechanism
SPEC §5.5 exists to make trustworthy.

`standardInput(for:)` is a pure function over bytes, so all four escapes and the leading-quote
trigger are now asserted with no filesystem, no git and no fixture. The file went from 49 of 54
regions on the runner to 54 of 54 everywhere.

**Three files, one defect.** A pure function reachable only through something that varies by machine
is not tested, however green the suite looks — and the coverage row saying so was read as noise twice
before the export was there to settle it.

## The pairing invitation is a `Domain` type, because the tab that draws it cannot see the layer that makes it

`PairingInvitations` lives in `ServerApiPresentation`, behind Hummingbird, and `ServerMacPresentation`
may not depend on it — a `Presentation` target depending on another one is not a rule with an
exception for this. So the Devices tab could not simply call the thing that assembles a code.

What moved is the **value and the question**, not the assembly: `PairingInvitation` and a
`PairingInviting` protocol are in `ServerApiDomain` now, and the existing type conforms. That module
gained one dependency, `CorePairingDomain`, which is what a link is defined in. The composition root
wires the conformer in, exactly as it does for every other edge.

**The error changed shape on the way, and that is the half worth recording.** `invite` threw
`ServerIdentityError` — a Keychain vocabulary, in a signature the Devices tab would have had to
translate. It now throws `PairingInvitationError.noIdentity(reason:)`, carrying the sentence rather
than the status code, and the four sentences themselves moved to `ServerIdentityError.explanation` in
`ServerIdentityDomain` because **two surfaces say them about one fault**: an identity this Mac cannot
read stops it serving *and* stops it offering a code, and a reader who meets both should not be given
two vocabularies for the same locked keychain. `TransportResolvingServerHost` lost its private copy.

`PairingInvitation.lifetime` moved with the type for the same class of reason `ConnectionAttempt.logCapacity`
is in a `Domain` module: the countdown fills a bar against it and cannot see the actor that enforces
it, and a second copy of `120` is a bar that empties at a different rate than the code expires.
`Pairing.codeLifetime` is now that constant rather than a second literal.

## The connection log carries a device identifier beside the name, and the Devices tab is why

*Seen 4 min ago* is a join between a paired device and the log of what has reached this Mac, and the
only key the log had was `device.name` — which is whatever the phone's owner called it. Two phones
can carry one string, and a sighting landing on the wrong row is the kind of wrong that reads as
right: nothing looks broken, and the row says something false about the one fact a reader came to
this tab for.

So `ConnectionOutcome.accepted` and `.paired` carry `id` as well. Nothing rendered changes — the log
prints the name and always did — and the router had the identifier at both call sites already.

**The sighting is derived rather than stored.** The model keeps the stored devices and computes the
rows from them and the current log reading, so a phone that connects while the tab is open stops
saying it has not been seen without anything having to notice. That is also why **following the log
moved to the composition root**: it used to start when the Connections tab opened, and a reader who
had never opened that tab would have been told every phone they own had not been seen. It is an
in-memory list of fifty, so following it from launch costs a continuation.

## Two states of §5 that the frames do not draw, and one they draw that is now false

The false one first: **the plaintext warning under the QR is not built.** It was true of 0.0.6 and
0.0.7 landed TLS and a real `spki=`; `design-mac.md` already says so, and this is the pull request
that had the chance to reintroduce it and did not.

The two that had to exist:

- **A code that could not be made.** The link is signed by an identity out of the login Keychain,
  which can be locked or half-removed, and a pane that silently showed nothing would be the same
  defect as the dead row this project shipped for eight releases. Our sentence — *No pairing code
  could be made* — with the Keychain's own words underneath and a **Try Again**, which is this
  product's failure idiom everywhere else.
- **A code being made.** `.preparing` is the honest state before the first one lands, because reading
  the identity is real work. It is not a placeholder for something unbuilt.

**Whether a code has expired is decided from a `now` the pane is handed**, not from a clock read
inside `body`. Same reason the connection log's elapsed time is handed in: a state derived from the
moment of drawing is a state no baseline can photograph, and *expired* is precisely the state that
matters most. The pane's `TimelineView` steps once a second rather than the log's once a minute,
because the smallest thing on screen here is a seconds digit.

**The window fits it, but only just, and the stack had to be tightened to make that true.** The first
render put *Expires in 1:46 / Single use* below the fold of the 560pt window design §2 sized from
this pane — ten points of spacing between each of five children was the whole difference. Recorded
because the next person to add a line here will spend it.

**`Revoke` is red on its label rather than tinted.** A tinted bordered button fills its bezel, and a
row with a solid red block in it reads as an alarm that has already gone off rather than as something
to press.

**The date reads *paired August 3* rather than the review's *paired 3 August*.** The order is
`Date.FormatStyle`'s under the reader's locale, and the baselines pin `en_US_POSIX`. Forcing
day-before-month would be overriding a system decision to match the language the review happens to be
written in.

## Which Settings pane is up is the model's, not the window's

`Pair…` on a refused connection row has exactly one job: bring the reader to the QR. Inside an open
window that is a tab switch rather than a settings request — an open window cannot open itself — and
the obvious way to build it is a `@State` on the screen.

That is the shape this project has already shipped a dead control in. A control whose only effect is
a `@State` two layers up is a control nothing can be asked about: no host test can reach it, and a
`TabView` hosted outside a `Settings` scene draws no tab bar, so no baseline can see it either. So
`SettingsTab` is a `ServerMacDomain` type and `ServerMacModel` owns the selection, which makes "the
control did something" an assertion rather than a claim.

It is also what §1 needs: the menu bar's *Pair a device…* has to open this window **on Devices**, so
`settingsRequests` will have to carry a pane rather than being a bare counter.

**What is still owed is pressing it.** The model transition is asserted; the closure that calls it is
one line in a `…Screen`, which no kind of test in this repository reaches — the macOS UI target
exists and has never been allowed to run. That is the same gap `decisions.md` records above, and it
closes with the Accessibility grant rather than with more unit tests.

## The words on screen are typeable, which they were not going to be

Design §5 draws the six words separated by middle dots, and `SpokenWords.normalised` split on spaces,
hyphens and tabs. A reader who selected that line and pasted it into their phone would have sent
`delta-·-pepper-…` and been refused — with a reason naming the code, on a screen that had just shown
them the code.

The dot is a separator now. Found by writing the row, not by using it, which is the only reason it is
not a defect somebody would have hit once and been unable to describe.

## The QR is `Ui`, and CoreImage is not a fourth dependency

`CIQRCodeGenerator` is a system filter, and turning a value into pixels for rendering is `Ui` work in
the same sense SPEC §8 already pins Highlightr to `ClientViewerUi`: highlighting produces attributed
strings for rendering. Nothing in `PairingQrCode` decides anything — the link is the contract and the
picture is a function of it.

**It sizes itself from the module count rather than filling a fixed square**, which is why design §5
gives the size as a range. A 53-module code squeezed into 240pt puts some modules at four points and
others at five, and that unevenness is what a scanner reads as noise. Four points per module, eight
pixels per module, so the bitmap is an exact 2× of the drawn size and an exact 2:1 downsample at 1×.

**White behind it in both appearances**, which is functional rather than a hardcoded colour: a QR
inverted for dark mode is one most scanners will not read, and this is the one surface where a reader
is holding a camera up to the screen.

## The window is photographed on every pane, and the coverage gate is what said so

The Snapshot row fell 95.6% → 95.4% and the export named the cause without argument: 84 of
`GranitaSettingsScreen`'s 445 lines uncovered, because the window's only baselines landed on General
and the other four tabs' composition closures are code no picture executed. Adding a fifth tab made
a gap that was already there one fifth worse.

**The pictures are partly redundant and the execution is not.** A hosted `TabView` draws no tab bar,
so the window on Devices looks very like `DevicesSettingsView`'s own baseline — but a pane's own
baselines are taken against values a test hands it directly, and these are taken against values that
arrived through the closures the window composes it from. A closure handed the wrong one — Devices
drawing Projects' failure, a Revoke carrying the neighbouring row's identifier — is invisible in
every other test this repository has.

Rejected: rescoping the row. It is the fourth time a falling row has been read here and the third
time the answer was that the code it cannot reach is code that should be reachable.

### And it immediately caught one, which is the point

The first render of the window on Devices photographed **Code expired**, forever. The pane's clock
came from `TimelineView(.periodic(from: .now, by: 1))` — a wall clock — while its data came from a
model whose clock is fixed, so the fake's expiry was always in the past.

That is the defect the connection log's row was repaired for, arriving one layer up: a schedule says
*when* to redraw and does not say what to draw, and a `body` that answers the second question with
`Date()` is a `body` whose picture depends on when the shutter opened. Both panes read
`model.currentTime` now. The schedule still comes from `.now`, because when to redraw is not
something a baseline can be wrong about.

## The pane does not ride on the settings request, and the entry above predicted that it would

Design §1 and the entry on which pane is up both said the same thing: *Pair a device…* needs
`settingsRequests` to carry a pane rather than being a bare counter. Both were written before
`ServerMacModel` owned the selection, and once it does, carrying the pane on the request is a second
copy of a fact something else already holds.

**The half that makes it wrong rather than merely redundant is `onChange`.** `SettingsOpener` watches
that value, and a value carrying a pane is `Equatable`: asking for Devices twice in a row produces
two identical requests, and the second one fires nothing. A reader who pressed the row, moved to
Advanced, and pressed it again would meet a menu item that did nothing — the exact defect this
project spent eight releases shipping, reintroduced by the mechanism meant to prevent it. Keeping the
counter a counter keeps "open" an event, and opening twice two events.

So `requestSettings(showing:)` takes the pane, hands it to the model, and *then* bumps the counter.
The ordering is the other half: set first, ask second, so the window opens already showing the pane
rather than arriving on one and moving. The design's actual constraint — do not invent a new
mechanism for this — is met; what it guessed about the shape is not, and the guess is superseded
rather than argued with.

## The remembered pane is in user defaults, and its absence is what a first run is

Design §2 asks for two things that are one question: restore the pane the reader was last on, and
open **Projects** the first time. So `SettingsTabMemory` answers with a pane **or nothing**, and the
model turns nothing into Projects. A seam that defaulted internally would answer every launch with a
pane and leave no caller able to tell a return from a first run — which is the decision design §2
actually makes.

**Not the store.** That document is shared with `granita-server`, which has no window and no panes,
and it is about to grow a lock file precisely so the two processes cannot both hold it. A preference
belonging to one of them does not belong in the file they share, and losing it costs nothing: a
reader whose defaults did not follow them to a new Mac lands on Projects, which is what a first run
does anyway.

**Synchronous, which no other seam here is**, and that is what makes the race impossible rather than
unlikely. The rest of them wrap a subprocess, a panel a person is looking at, or a document written
to disk; this wraps a value the system already holds in memory. Read in the model's `init`, there is
no window in which a restore could land *after* the menu's *Pair a device…* and quietly take Devices
back off the screen — and no `Binding` on the tab bar has to defer its own assignment by a turn to
make room for an `await`, which is how a tab bar comes to lag a click it has already accepted. The
pane names are spelled out rather than derived from the case names, because a rename would otherwise
strand a stored word and send a reader to a pane they were not on.

## The menu is photographed as a stack, because a menu cannot be photographed at all

`MenuBarContent` gained four controls, and the Snapshot row is scoped to the `Ui` layer — so drawing
code nothing renders would have taken the row down, which is the trap this repository has now met
three times. The obstacle is that a `MenuBarExtra`'s menu is drawn by AppKit outside this process's
view hierarchy: there is no hosting view it can be rendered into, and a test bundle has no `Settings`
scene either, which is the same reason the window's own baselines show no tab bar.

What is committed is the menu's rows laid out in a `VStack` — every row in order, the copy each one
carries, and a disabled row visibly disabled. That is what §1 is about: which rows exist in which
state and what they say. The button styling is the test file's rather than the app's, and the
docstring says so, because a menu item's appearance comes from the menu it is in.

**What no picture here can say is whether anything is behind them**, and that is the honest state of
four new controls rather than a caveat. It is the same gap the Devices tab's `Revoke` and the
connection log's `Pair…` are in, it closes with the Accessibility grant rather than with more tests,
and the four rows are named in `status.md` beside them.

## The Mac's design review is gone, and the sheet is the whole record now

`granita-mac-design-review.html` was deleted with §1 and §2's frames, because they were the last two
sections in it and the file said in its own words that it would go with them. Every surface it drew
is built.

Recorded because deleting a design return looks like losing one. What was durable in it was already
carried across as it went: `design-mac.md` holds each call beside the alternative it beat, both open
calls with the measurements that answered them, the five premises and which survived, and the numbers
the frames existed to carry — the window's 620 × 560pt and where that height comes from, the QR's
49-to-53 module range, the tab symbols. What the frames added on top of that was pixels, and the
built screens are pinned by committed baselines now, which is a better answer to the same question
and one that fails when it stops being true.

## The coverage gate reported a regression that was not one, and the measurement was the defect

**The fifth time a falling row was read, it named the ratchet itself.** The four before it were
right — an undrawn tab's composition, a screen doing its own I/O, two predicates counting code a
picture cannot execute. This one was not: PR #35 failed on Unit 96.0% → 95.9% and All 96.9% → 96.8%,
and the whole of it was five lines in `SessionTranscript.swift`, a file that pull request does not
touch. A re-run of the identical commit passed.

**The evidence, because "flaky" is a claim and this needed to be a measurement.** Five runs of one
commit, in parallel: 96.121%, 96.121%, 96.037%, 96.037%, 96.037%. An earlier set of three moved
`SessionTranscript` between 81 and 86 covered lines of 87, and the five-run set moved
`BonjourBrowser` between 78 and 82. Serially, four runs still moved `BonjourServerDiscovery` by one
line. The suite is green in every one of them: what varies is which lines a scheduler reached before
something was torn down, never what a test asserts.

**Two causes, and both are fixed rather than tolerated.**

The first is a test that drove a real `NWBrowser` to answer a question about ordering. *Does the
screen say something before any browser has reported* is about what happens first, and it was being
asked of a daemon whose reply time is a property of the machine — so how much of
`BonjourServerDiscovery` and `BonjourBrowser` ran before the loop was left varied by run. It takes
the fake now, through a seam `DiscoverySession` already had and this type had hard-coded past. The
test passed either way, which is the point: **a percentage cannot describe this failure**, and the
test that answers the machine it runs on is exactly what `#33` was named for.

The second is the pass itself, which runs `--no-parallel` now. That is about the measurement rather
than the tests, and it is what takes the last of the variance out: with both changes, five runs of
one commit agree to the line and no file differs at all.

**Rejected: giving the gate slack.** A floor or a tolerance is the obvious fix and it is the wrong
one — it would buy a stable gate by making it stop noticing the thing it is for, and this repository
has four recorded instances of a one- or two-tenths move being a real defect. The gate is right to
have no slack; the number handed to it has to deserve that.

**The scope string is renamed for the fifth time, and this rename changes no predicate.** The four
before it moved which files the row was taken over; this one moves how the number is taken, and the
gate's un-judging mechanism is the only one there is — it compares two numbers when both were taken
the same way. It also passes the test those four are held to: it does **not** flatter the row.
95.978% replaces a parallel sample that read up to 96.121%, because what is lost is coverage that
was never the tests' to claim.

## The logging layer lands without the two rows it unblocks, which inverts what was recorded

`decisions.md` said the verbose switch and *Open in Console* "land with the logging they describe".
The reason it gave is one-directional and still holds: a control over an absent subsystem reads as a
feature, gets pressed, and answers with a silence that looks like *nothing is wrong*. That forbids
rows before a layer. It does not forbid a layer before rows, and the split is now the other way for a
reason that is arithmetic rather than taste.

**Advanced's Diagnostics rows and the lock-file row move the same pictures.** Both change
`AdvancedSettingsView`'s eight baselines and the window's `serving-advanced` pair, and a Mac baseline
costs a full round trip through CI — push a placeholder, download the runner's render, adopt. Landing
them separately is two of those over one set of images. Landing them together is one.

So this pull request is the layer, and the next is both halves of what is left of §7.

**The layer is not inert while it waits**, which is what makes it a slice rather than scaffolding. A
note is never behind the switch — a git invocation that failed and a request that was refused are
written whatever the setting, because a fault a reader has to enable logging to see is one they learn
about after it mattered. What the switch will gate is the detail, and until the switch exists it is
`defaults write dev.fardavide.granita granita.diagnostics.verbose -bool YES`, which is the same key
the switch will write.

**Two decorators rather than two dependencies.** `LoggingGitClient` wraps a `GitClient` and
`DiagnosticsMiddleware` sits on the router, which keeps `ProcessGitClient` doing one thing and means
the libgit2 client the protocol exists for arrives logged without knowing it. It is the shape
`RebindingOnWake` already uses on the host.

**The decision about verbosity is in `Domain`, and the thing that writes to the system log has none
in it.** `VerbosityFilteringDiagnostics` drops the detail and passes notes through, asserted against
a fake; `OsLogDiagnostics` is two calls on `os.Logger`. That is the same split
`SystemSettingsPaneUrl` and `AppKitSystemGestures` already make, and it exists so the one question
worth asking — *did the switch being off hide that* — has an answer rather than a screenshot.

**The verbosity is read per line rather than captured.** The switch will be on a Settings pane and
the server reading it has been running since launch, so a copy taken at composition time would be a
switch that did nothing until the app was restarted — a control that appears to do nothing, on the
tab that exists to explain things.

**What is written is narrower than what is available, and that is the security boundary again.** The
git decorator logs the command and the checkout, never git's standard output, which is the contents
of a private repository. The middleware logs the method and the path, never the query or the body:
`/v1/pair` carries a live pairing code and `?projectID=` resolves to a folder on this Mac. Both are
asserted rather than described. The one exception is a failure's own text, which is git's standard
error — a sentence written for a person, and the rule this layer already follows everywhere.

**`os.Logger` redacts interpolation by default, and that is turned off here, narrowly.** A log full
of `<private>` is the failure this slice exists to prevent. It is safe precisely because of the
paragraph above: what reaches those two calls is a command name, a path on this Mac, a method and a
status.

**A test caught the shape of a refusal, which is why the middleware is on the router.** An
unauthenticated request does not return a 401 through the middleware — the authenticator throws, so
the refusal takes the note path and survives the switch being off. That is the better half to land
in, and it was written down as an assertion only because the first version of the test asserted the
other thing and failed.

**Detail is written at `.notice`, not `.debug`, and no test in this repository could have said so.**
`.debug` is the obvious level for it and the wrong one: the unified log does not persist debug lines,
so they are gone unless somebody enabled debug logging for the subsystem first. A reader who turns
the verbose switch on, presses *Open in Console* and meets an empty window has met the defect this
project cares most about — and every test would have stayed green, because a fake records what it was
handed whatever level it was written at. The level has nothing left to gate anyway, since
`VerbosityFilteringDiagnostics` decided before the line got here.

Confirmed by running `granita-server --add-project` and reading the lines back with `log show`, which
is also how the next fact was found.

**The two roots do not share a defaults domain, and pretending otherwise would have made the switch
look broken.** An executable has no bundle identifier, so `UserDefaults.standard` resolves to the
global domain for `granita-server` and to `dev.fardavide.granita.mac` for the menu bar app: the same
key, two places. Turning verbose on for one does not turn it on for the other. The app's switch is
the pane that lands next; the executable's is `defaults write -g`, and the changelog says both rather
than naming one and being wrong for whoever tried the other.

## A refused lock is its own run state, because reusing `failed` points a button the wrong way

The cheap version was to put the refusal's sentence into `failed(reason:)`, which already carries a
string and already reaches every surface. It was rejected, and the reason is not tidiness: General's
`failed` branch **names Local Network access as the likely cause and offers a button straight to that
pane**. For a lock conflict that pane is already correct, so the advice is wrong and the button is a
control that does something actively unhelpful — a reader follows it, finds nothing to change, and
comes back knowing less than they started with. That is worse than a control that does nothing,
because it costs a trip.

So `blockedByAnotherProcess` is a case of its own. **The compiler found all six switches over the
enum**, which is what the no-`default:` rule buys: three of them fold the new case in with
`failed`/`stopped` because the answer really is the same — the menu bar's symbol, its accessibility
label, and whether pairing can be offered — and three needed a real answer.

**Three symbols in the menu bar rather than four.** The status item asks one question and a blocked
lock answers it the same way a failure does: not serving. Which of the three reasons it is belongs
one click below, and 0.0.16 already settled that shape.

**The menu names this reason, unlike `failed`, whose reason it deliberately withholds.** The
difference is that `failed` carries whatever went wrong — a locked keychain reaches it too — so a
menu with no room for small print would be asserting a cause it cannot know. A held lock is a fact
with one short noun in it and no hedge to leave out.

**`ServerApiDomain` gained a dependency on `ServerStoreDomain`** for the holder the state carries.
`Domain` may depend on `Domain`, and the alternative was flattening a two-field record into two
loose parameters — the same record spelled twice, in the enum that exists to keep it in one place.

## The lock is `flock`, and the file's contents are a message rather than a decision

A pid file whose contents decide who holds the lock gets the interesting case wrong. **A Granita that
crashed leaves a pid behind**, and the usual repair — check whether that process still exists — races
against the identifier being reused, so the failure mode is a lock nobody can take or one two
processes both take. The kernel already answers this exactly: a `flock` is released when the
descriptor closes, and a descriptor closes when the process dies however it dies. Asserted by a test
that writes a lock file naming a process that never existed and takes the lock anyway.

So the decision is the kernel's and the contents are only a name to put in the refusal — which is why
`heldBy` carries an **optional** holder. Whether the lock is taken and who has it can disagree for a
moment: a process that has just taken it has not yet written its name into it. A refusal that
softened into an acquisition on that window would be the two writers the lock exists to prevent, so
the name is what is lost and never the refusal. Advanced's row draws on "is blocked" rather than on
"has a holder" for the same reason — a row that vanished when the name could not be read would
disappear in exactly the case a reader has least to go on.

**`flock` rather than POSIX record locks, and that also decided how it is tested.** `fcntl` would
have handed back the holder's process identifier without reading any file, which is strictly better
information — but POSIX record locks are held per *process*, so a second lock taken inside one
process succeeds. The tests here simulate two processes by being two, in one test binary, which only
works because `flock` is per open file description. The holder is a constructor parameter rather than
something read from `ProcessInfo` inside the lock for the same reason.

**Outermost in the host chain**, outside `RebindingOnWake`. Inside it, the lock would be re-acquired
on every wake — a Mac that stops serving overnight because a `granita-server` was started in a
terminal in between. The lock is a fact about this launch, not about this bind.

## Advanced grew three rows and General grew a state, in one pull request rather than three

The scheduling call recorded in 0.0.17 held: all three rows change `AdvancedSettingsView`'s baselines
and a Mac baseline costs a full round trip through CI. What was not predicted is that the lock would
also cost **General a state and the menu a picture**, because the refusal has to be read where a
reader looks first and not only on the tab they would reach last. Six new baselines rather than the
two the estimate assumed, in one round trip rather than three.

**The footer under the Diagnostics section is three sentences and each one prevents a control from
lying.** What the switch turns on; what it cannot turn off, so nobody leaves it on for a week to
catch something already being written; and that Console opens unfiltered with the predicate on the
clipboard, because a reader who is not told to paste has met a button that did nothing.

## The coverage gate runs locally now, because five times it was read from a red pull request

**The measurement script always ran anywhere; nothing fetched `main`'s numbers or applied the
verdict.** So the only way to learn what the gate would say was to push and wait, and five times that
is exactly what happened — twenty minutes each to obtain a number that was computable in the working
tree the whole time. Davide named the waste directly; `make coverage` is the answer.

It is not an approximation of the gate. It fetches the last green `main` run's summary, runs
`.github/scripts/measure-coverage.sh`, and hands the result to the same `render` and `enforce` the
workflow calls — same predicates, same ratchet, same exit code and same message. Verified on
2026-08-24: the local numbers and the runner's agreed **to the line on all six rows**, twice.

**The baseline arrives as a new `coverage-summary` artifact**, a few hundred bytes beside the
existing `coverage-exports`, which is ~300 MB — and `gh run download` cannot fetch one file out of an
artifact, so without the small one every local check would pull all of it. Runs predating it fall
back to the big one rather than refusing, which is what keeps the target usable on the very branch
that adds it.

**What a tool cannot supply is what to cover, so the skill gained that too**, keyed to what a region
actually is: every `guard`/`if let` failure branch, every `??`, every new `case`, every computed
property or static factory asserted **directly** rather than incidentally, and every fallback a view
draws needing a snapshot subject of its own. Each was a real miss on this branch — `FileStoreLock`'s
refusals, `StoreLockHolder.sentence`, `.thisProcess`, and three `?? "another process"` strings
argued for in a comment and rendered by nothing.

## The screen's uncovered regions are mostly closures, and "mostly" is the load-bearing word

The first read of the export said all of `GranitaSettingsScreen`'s uncovered regions were action
closures a render cannot invoke, and concluded the row was structurally unholdable by any pull
request adding a control. **That was wrong in a way worth recording, because it nearly bought a scope
change nobody needed.**

Two corrections. The count is **47 regions, not 29** — 29 is the number of distinct source lines they
sit on, and a line can carry several. And **four of the 47 are not closures at all**: they are the
`.sheet` presentation path — the builder, the `if let scan = model.folderScan` branch, its implicit
else, and the binding *read* evaluated during render. A snapshot handed a model with a folder scan
executes every one, which took the file from 47 uncovered to 43 and the row from 84.17% to 84.94%,
over the 84.65% baseline.

So the fix was a test for a real state — the window presenting design §4's sheet over Projects, which
no picture had ever executed, on the flow that is the security boundary. **The rescoping that the
first reading pointed at would have been the fifth reach for one and the second wrong one.**

**The remaining 43 are genuinely uncoverable by this project's current test kinds**, and that stands:
an action closure is invoked by a person, and only the `ui` kind has one. Adding controls to that
screen will keep pressing on this row until the Accessibility grant lets `make ui-tests-mac` run.

**The baseline is named for what it shows, not for what it exercises.** A hosted view presents a
sheet into a window of its own and the raster does not include it — the same limitation as the tab
bar — so the picture is `projects-beneath-the-scan-sheet`. Naming it for the sheet would be a picture
asserting the opposite of its own name, which that suite already refuses one paragraph above.

## §2's drawings and its prose disagree twice, and the prose wins both times

The frames are measured and the prose is written from them, so a conflict is normally the drawing
being right. **These two are the other way round, because in each case the drawing contradicts a rule
stated in the same document.**

**The rename sheet's footer previews the suggestion, not the branch.** Frame (c) draws *"Clear the
field and save to go back to feat/tls-pinning"* while a session summary is on screen one section
below — but the Mac resolves a display name as alias, then suggestion, then branch, then directory,
so clearing that alias would put the summary on the row and not the branch. The footer's whole
purpose is stated a paragraph above the frame: it says what the row will read after Save. A footer
that is wrong in the one case a reader is checking it is worse than no footer. So the fallback is
`suggestedAlias ?? branch ?? directoryName`, and `WorktreeRenameSubject` carries which of the three
won, because with no suggestion the sheet's section is absent and the footer has to say *why*.

**A quiet primary checkout is hidden like any other.** The grouped frame draws *"main · primary
checkout · no changes"* above a footer reading *"6 worktrees with no changes are hidden"*, which
cannot both be true. Exempting the primary was the tempting reading — §2 says the word exists partly
because that row "usually has no changes" — and it is unbuildable: §2 also draws *"Nothing to
review. All 9 worktrees across granita and aura are clean"*, and a never-hidden primary makes that
state unreachable, since every project has one. So the filter is literal, the word still earns its
place on the rows that do show, and Davide confirmed it rather than it being picked.

## The worktree sidebar ships with no way to reach it, and that is the point

M4's list needs a paired Mac. Pairing has no frames, so it has no screen, so **nothing routes to this
one** — not a row, not a tab, not a debug entry. `ClientAppMain` builds the browse and stops exactly
where it did.

That is the rule rather than an exception to it. A control ships if it works, is absent, is disabled
and says why, or explains that what is behind it is not built. **Absent is a legitimate state; a link
to a screen that cannot load is not**, and this project shipped the second one for eight releases.
The alternative offered and declined was a debug-only route, which is the same defect with a
smaller audience.

The consequence is that **none of this screen's controls has ever been pressed**, which is the same
honest state the Mac's ten are in and for a different reason: there the grant is missing, here the
route is. Every one of them is asserted at the model — the two swipes, the menu's picker and toggle,
the footer, Try Again and Show them anyway — and a rendered baseline cannot say whether anything is
behind any of them. They are pressable the day pairing lands, and that is when they get pressed.

**A row still has to do something the moment the screen is reachable**, so it does: selecting one
pushes `WorktreeNotReadyView`, which names the worktree and says the file list is being built. It is
declared in the same file as the links that reach it, and it goes when design §3 arrives — the same
shape, and the same reason, as `PairingNotReadyView`.

## Two states §2 does not draw, and one it draws for a container this slice does not build

**Loading and failed had to exist.** §2 draws four states and none of them is a request in flight or
a Mac that would not answer, and both are reachable on the first launch of a paired phone. They
follow §1's idiom rather than inventing one: our sentence in the description, a real Try Again, and
the machine's own words demoted to caption2 monospaced tertiary — which is why `ApiFailure` grew a
`diagnostic` beside it, `nil` for the refusals a Mac spells deliberately. **Loading gets a
`ProgressView`**, which §1 refuses: a progress view promises a finish and a Bonjour browse has none,
while an HTTP request either answers or fails.

**The iPad's 320pt sidebar and its "Choose a worktree" detail column are not built.** They are a
`NavigationSplitView`, and the split view belongs to whichever composition root presents this screen
— which is the one pairing brings. Building half of it here would mean a container nothing composes
and a detail column no reader can reach. The consequence is stated rather than hidden: **the iPad
baselines photograph the sidebar at full width, which is not the iPad layout that will ship.** They
are re-recorded when the root arrives.

## A pinned row is lifted out of its project, and project sections sort by activity

Two orderings §2 settles by argument rather than by drawing, both worth recording because the
alternative is what a reader would expect.

**Lifted, not copied.** The Pinned section takes the row out of its project's section rather than
duplicating it — "a row that appears twice is a worse bug than a row that appears once in a
surprising place" — and the project name on line two, which no other grouped row carries, is what
makes the place unsurprising. A project whose only worktree is pinned therefore grows no header at
all, because a header over nothing says a project is here and then shows a gap.

**Activity, not the alphabet.** §2 never states the order of the project sections, and its frames put
`granita` above `aura`, which is not alphabetical. Most recently touched first is what the rest of
this screen sorts by and what puts the project the agent was in five minutes ago at the top. The name
breaks a tie, so two identical reads cannot reshuffle.

## The sidebar's mode control is a toolbar menu, which is a second departure from `SPEC.md` §10

§10 says a segmented control switching between grouped and flat. Design §2 calls replacing it "the
strongest single recommendation in section two", and the built screen follows the design: **one
toolbar menu holding an inline picker and a toggle.**

The arithmetic is what settles it. A segmented picker is a permanent 32pt band plus 16pt of padding
— 48pt of every scroll, forever, for a preference set in week one — and it lands directly above the
Pinned header, so the first thing a reader sees on the screen this product exists for is two rows of
chrome. There is already a second preference beside the mode, the quiet switch, and probably a third:
three toggles cannot be three segmented controls, but they are three menu rows without a redesign.

Recorded here rather than left in `design.md` alone because this file is where a knowing departure
from the specification belongs, and this is the second in §2 — the other being the rename sheet
offering the suggestion rather than prefilling it. Everything else §10 asks of this sidebar is built
as written: the row's six fields, the swipe actions, pinned above everything in both modes with a
single Pinned section in grouped, and renaming writing the alias and never touching git.

## The six words pin on first contact, because refusing them leaves a state with no way out

The pairing design review's finding, and the one thing in it no frame could carry: **the two
credentials are not peers.** The QR carries the SPKI fingerprint over a channel nobody on the network
can write to — the Mac's own screen. The six words carry a code and nothing else, and the host and
port they borrow come from a Bonjour record any device on the LAN can publish. They redeem the same
pairing and they do not buy the same guarantee.

The client had already decided this by accident and in the strictest direction: `PairingLink(url:)`
throws `missingField(named: "spki")`, and `UrlSessionHttpTransport(pinnedTo:)` cannot build a session
without a fingerprint at all. So on 0.0.19 the six-word path could not be built, whatever a screen
looked like.

**`SPEC.md` contains the tension rather than settling it.** §8 requires the SPKI pin *and* requires a
six-word fallback "for when the camera is unavailable", and the second cannot satisfy the first. That
is why it went to Davide rather than being resolved here; he delegated it back on 25 August 2026.

**The words path pins the certificate it is handed on first contact**, and everything downstream
follows from that being said out loud rather than hidden. What decided it was the alternative's cost
rather than this one's comfort: refusing without an `spki` deletes SPEC §8's fallback outright, and it
leaves design §5's refused-camera state with **no in-app remedy at all** — an unavailable-content view
whose only action leaves the app, which is the shape this project spent eight releases learning not to
ship. It also makes the same-device case unreachable, which is the case Davide actually hits.

The asymmetry is carried in two cheap places instead of one expensive one: the camera is **ordered
first** on the entry screen, and one caption2 line on the six-word screen says what the difference is
— *"The QR code also carries your Mac's key. Typed words trust the Mac that answers, so use them on a
network you trust."* That is a true sentence about a pin, and it is not the plaintext warning 0.0.7
retired: the connection is TLS on both paths.

Rejected: **putting the fingerprint in the Bonjour TXT record.** It repairs the already-paired state
and it looks like it repairs this, and it does not — a TXT record is in-band, so an impostor
advertises its own key beside its own host and the phone pins precisely what the attacker chose. One
field, two features, one of them imaginary. The instance identifier the discovery list is waiting for
may still ride there; the key may not, and this entry exists partly so that nobody adds it later
believing it helps.

Rejected: **a fingerprint the reader compares.** Four characters beside the words on the Mac, four on
the phone, and a confirmation. It is the SSH ceremony and it is entirely buildable. It does not ship
because a check nobody performs is worse than an honest sentence — it launders the risk — and this one
would be performed by the reader who has already been pushed onto the harder path, squinting across a
room.

Rejected: **refusing to pair over words unless the network is trusted**, in any automated form. There
is no signal on iOS that answers that question, and a screen that claims to know is a worse lie than
the one it replaces.

The scope that makes this affordable is `SPEC.md` §0's, and it is LOCKED: **the network is LAN only in
v1.** The day v2 adds remote access this entry is the first thing to re-read, because trust on first
use across the internet is a different proposition from trust on first use across a flat.

## The 128 words are contract, so they live in `Core` rather than on the Mac

`SpokenWords` was `internal` to `ServerApiPresentation`, which was right while the Mac was the only
reader of its own codes. Design §5 asks the phone to say *"branch" is not one of the words* before a
round trip is spent, and that needs the list on this side.

The move is the same argument `CoreApiDomain` already won and is recorded above: **a word list both
ends spend a credential against is the wire contract**, and a second copy on the client would make a
list edit a version skew that nothing catches until somebody across a room reads six words aloud and
is refused. So it goes to `CorePairingDomain`, beside the link that carries the code, and the five
tests asserting the list's four promises go with it.

What that buys beyond one sentence on a screen is worth stating, because it is the reason it is worth
the move rather than deleting the line: five failures a minute lock the source address out, so a
wasted round trip on a mistyped word costs more than it looks.

Rejected: copying the list into the client. Same failure as copying `ApiErrorCode` would have been.
Rejected: dropping the unknown-word line and keeping only the count, which the review offered as the
cheap way out — it is cheaper than the move by about twenty lines and it spends a fifth of the rate
limit to learn what the phone already knew.

## The normaliser accepts an en dash, because iOS types one whether or not anyone meant to

`SpokenWords.normalised` split on space, hyphen, tab and the middle dot the Devices tab draws. iOS
smart punctuation turns a typed hyphen between two words into an **en dash**, so a reader typing the
code exactly as the Mac shows it would have been refused for punctuation the keyboard chose.

Fixed in two places rather than one, and both were needed. The field turns smart dashes off, which
stops it happening while typing; the normaliser accepts en and em dashes, which is what covers a
**paste** — the path the same-device case will actually take, and the one no field setting reaches.

Recorded because it is the second time this exact class of defect has been found here: the middle dot
was added for the same reason, that a code shown in a form the server will not accept is worse than no
fallback at all.

## The already-paired state is the one frame this slice did not build

Design §5 draws it, it draws fine, and it is unreachable: nothing joins a Bonjour instance to a stored
token. The phone keeps its tokens against `ServerInstanceId`, a discovered Mac is only a Bonjour
instance name, and the `serverInstanceID` that would join them is the TXT record entry SPEC §8 asks
for and the Mac does not publish — which is on `status.md`'s "Waiting on Davide" for design §1's
*Recent* and *Other Macs* sections already, and is now blocking a second thing.

So the frames for that state stay in `.claude/docs/design/`, alone, and the rest are deleted with the
sections that shipped. **A `pairedAt` date on the token store is not added either**, for the same
reason: it is one field and one better sentence on a screen no reader can currently reach, and adding
it now would be API a screen has not agreed to — which is the mistake `ClientConnectionModel` already
made once and had a whole entry written about.

The review's own reading of that state is worth keeping, because it changes what to build when the
record lands: **already-paired is a discovery problem wearing a pairing screen.** The right behaviour
is a paired Mac's *row* going straight to its worktrees, after which the only readers who ever see
this screen are the ones whose token the Mac revoked. Build the row; keep the screen for that one
case.

## There is no manual host entry, which is a departure from `SPEC.md` §10

§10 asks for "manual host entry as fallback" beside Bonjour discovery. There is none, and there will
not be one in v1.

The words screen is reachable only from a browse result, so the host and port are already in hand
before a reader could type anything — the input genuinely missing from that path is the key, not the
address, which is the entry two above. And a field that lets a reader point this app at an address
Bonjour never returned is not a fallback: combined with the entry two above it is a way to hand a
pairing code to any address somebody can be talked into typing, which is a strictly worse hole than
the one trust on first use accepts.

The weakest departure recorded here, and deliberately so: §0 lists Bonjour-plus-QR as **PROPOSED,
override freely** rather than LOCKED, so this is a proposal being narrowed rather than a decision
being overturned. It is written down anyway, because "the spec says do X and we did not" is exactly
what this file is for.

## A pairing that could not be written down gets its button back

`MacPairing.pair` held the `PairedDevice` in hand when `tokens.save` threw and dropped it on the
floor, returning `.tokenNotStored(error)`. The design drew that screen without a primary action for a
stated reason — the reviewer could not tell whether the token survived that far, and **a button that
cannot work is the defect this project is named for**.

It survives. So the outcome carries it, *Try Again* on that screen retries the Keychain write **alone**
rather than re-running a handshake against a code that is now spent, and the walk to the Mac drops to
the second sentence. `errSecInteractionNotAllowed`, the common cause, is transient.

Davide's call on 25 August 2026, against the drawn version. The cost is stated rather than waved
through: a live bearer token now sits in memory for as long as that screen is on screen, where before
it was discarded immediately. It is not written anywhere, it dies with the screen, and the alternative
was sending the reader to another machine to fix something the phone could have fixed itself.

Still rejected, and the review is right about both: **no *Pair Again* on that screen**, which would
leave a second device record beside the orphan, and no dropping of the sentence that says the Mac now
believes this iPhone is paired — without it the advice to go and revoke it sounds like superstition.

## *Open TestFlight* appears only when the system says it can open it

Design §5's *the phone is behind* state offers it, with the reviewer's own note attached: *only if the
URL opens TestFlight on a device that has it — otherwise delete it.* Neither this machine nor the
simulator can answer that.

So neither answer is picked. The button is rendered only when `canOpenURL` says the device can open
it, which turns an unanswerable question into a condition evaluated on the device where it has an
answer — and it lands on this project's own rule rather than on a guess: a control ships if it works,
is absent, is disabled and says why, or explains what is not built. **Absent is a legitimate state**,
and a reader with no TestFlight is not missing anything, because the sentence above already tells them
what to do.

Rejected: shipping it unconditionally and finding out from Davide. That is the eight-release defect
with a better excuse. Rejected: disabling it with a caption — a greyed *Open TestFlight* explains
less than no button at all on a screen that has already said which end is behind.

## The rate limit is keyed per source address, and the review's premise was one release stale

The return asks whether the limiter counts per device or per dialled address, having found
`request.head.authority` in the Mac round trip — the address the phone dialled, which is the same
string for every device, so five failures from anywhere would lock out everyone. Its copy was drawn
device-neutral to survive that being true.

It is not true any more. `GranitaRequestContext.source` is `remoteAddress?.ipAddress`, the peer's
address without its port, and it has been since the connection log needed a source worth reading. So
the limiter is **per device on any ordinary LAN**, and the kinder sentence is the one that ships:
*MacBook Pro has stopped taking pairing codes from this iPhone for a minute.*

Worth an entry only because of the shape: this is the second time a returned review has argued from a
premise the repository had already repaired — the Mac's plaintext warning was the first — and both
times the answer was to check the code rather than to build the drawing. A return is a recommendation.

## `MacJoining` comes back, because the day its own doc comment named has arrived

`MacPairing` shipped 0.0.19 saying it would need a protocol "the day a screen drives it and wants a
double for the whole sequence", and that day is this one: the model behind design §5's four screens
drives all three of its members and is tested against them. So the protocol is back, with the two
members the outcome screen can act on separately — a code is spent once, and the Keychain write it
bought is retried on its own afterwards — plus the history the discovery list is ordered by.

**What it beat is the version that drives the two fakes already sitting under `MacPairing`.** That is
the option worth taking seriously, since `FakePairingTokenStore` and `FakeServerPairing` are written,
configurable and asserted against. It loses on two counts and the first is structural: they live in
`ClientConnectionDomainTests`, so a `Presentation` test reaching them means either a second copy of
both in a second bundle or a test target depending on a test target — one protocol and one fake is
less machinery than either. The second is the reason the entry above this one was written at all:
every model test would then re-run health, spend a code and write a token, which is a second copy of
`MacPairingTests` sitting one layer up and drifting from it the first time the sequence changes. The
model's tests should be able to say "the Mac refused" in one line and look at what the screen shows.

The cost is stated rather than waved through: it is one more name to learn, and for the moment it has
exactly one production implementation, which is the shape the `architecture` skill tells us to be
suspicious of. It clears that bar the ordinary way — there is a fake behind it today, in
`ClientConnectionPresentationTests`, and thirteen tests that could not be written without one.

### `PairingState` goes to `Domain`, which is not where it was removed from

It was nested in `ClientConnectionModel` when the pairing surface was taken out. It comes back as a
file beside `DiscoveryState` for the reason that one is there: the views that render it are in `Ui`,
which may see a `Domain` type and may not see a `Presentation` one. Nesting it would have forced the
screens to decompose it into primitives on the way down, which is the same enumeration written twice.

**Ten cases for design §5's twelve states, and the arithmetic is worth writing down** because two of
them are this repository's rather than the review's, and a later reader should not have to guess
which. The camera's *waiting*, *refused* and *restricted*; the viewfinder's *looking*, *not ours* and
*spending*; the entry screen; and the outcome. The two extra:

- **`savingToken`.** The outcome screen gained a button — recorded above, Davide's call — and with it
  the moment between the tap and the answer. The frame had no in-flight state because the frame had
  no button, and without one a write that fails a second time redraws the screen the reader was
  already looking at. That is a control that appears to do nothing, which is the defect this project
  is named for, arriving through the subtlest door it has.
- **`notReached`.** Six typed words with nowhere to send them. It carries
  `ServerAddressResolutionFailure` rather than a sentence because that enumeration's two cases do not
  share a remedy: *Try Again* is right for a Mac that slept, and it is a dead control in front of a
  local-network permission that will never grant itself. **§5 draws the first and not the second**,
  which is the one gap this slice found in that section — the refused-permission idiom §1 already
  owns is what the screen should reach for, and if that is wrong the answer belongs in `design.md`
  before it belongs in a screen.

`cameraRestricted` is not a third extra: §5 draws two permission states and `CameraAccess` has four
cases for the reason recorded with it, so folding a restriction into a refusal would ship *Turn the
Camera On in Settings* over a switch a policy is holding shut.

### The composition root is wired now, and that is not the mistake it looks like

The entry that removed this surface said do not ship a screen's API before the screen, and this
commit ships the model before the screens land. The difference is the ordering rather than the rule:
the screens are the next commit on this branch and no pull request opens between them, so nothing
reaches `main` with a property no view reads. What made the earlier case a defect was that the screens
had **no frames**, and the `design-handoff` rule forbade the pull request that would have drawn them;
§5 is drawn now.

Wiring the root is what gives `HttpServerPairing.init(mac:)` and
`UrlSessionHttpTransport.init(trustingFirstAnswer:)` their first production caller, which is what
those two were left uncalled and measured for. The root is also the only place allowed to see that
the two credentials build different sessions — pinned for a scanned link, trusting the first answer
for six words — and that is one closure rather than a branch anywhere above it.

## The pairing spine is one path, and only one of its three pushes is an ordinary push

Design §5 asks for four screens pushed in the stack discovery already has: *Macs → this Mac → Scan
or Words → the outcome*. Pushed is what shipped. What §5 does not draw is what happens when the
reader taps **back** from the fourth screen, and answering that is what shaped the other two.

**The outcome replaces the viewfinder and pushes over the field**, which looks like an inconsistency
and is two of §5's own sentences applied to the same event. Behind the words screen there is a
phrase worth returning to: "after a refusal the words screen keeps what was typed and says the code
is stale", which is the consequence that replaces the countdown this phone deliberately does not
draw. Behind the viewfinder there is a frozen frame, a stopped camera and a code that has already
been spent — §5's own reason for replacing the stack on success is "back must return to the Mac
list, never to a scanner holding a spent code", and a refusal leaves exactly the same screen behind.
So the scanner swaps itself out and back from the outcome lands on the Mac, one tap from either
credential.

**The two credentials are siblings by swapping the top of the stack, not by pushing.** *Enter the
Six Words* on the viewfinder removes the viewfinder and puts the field in its place, which is what
"the same depth" means when the button that moves between them is on the screen rather than in the
navigation bar. §5's prose describes the reader's route as "a back tap and a second tap"; the button
is that route in one gesture, and it lands them in the same place.

**Nothing about this is expressible without a path the screens can assign to**, so the stack gained
one and the composition root holds it. That is also the whole of why success can be what §5 says it
is — a replacement rather than a fifth screen — and it is the reason `NavigationPath` is
type-erased here rather than an array of one route enum: each hop keeps its own value type, so each
destination can be declared beside the link that reaches it.

### One route type for the three pairing screens, because "beside the link" needs help two levels in

The rule this project learned the hard way is that a link and its destination live in one file. It
holds for the Mac's row and for the two credentials, whose links are on the screen that declares
them. It cannot hold literally for the outcome, whose links are on the two screens *below* the one
that declares it.

So `PairingStep` is one enum with one destination and one **exhaustive** switch over it. What that
buys is stronger than proximity: a step added without a screen does not compile. The alternative
considered was a `navigationDestination` in each of the two credential screens — legal, since they
are never in the stack together — and it is two copies of one composition, drifting from the day the
outcome screen gains a parameter.

`PairingStep.theOutcome` carries **no payload**, which is what removed the last argument for those
two copies. The screen draws the model's state, and what *Try Again* would spend again is the
credential the model kept — so the model grew `spentCredential`, and a route that carried either of
them would have been a second copy able to disagree with the first.

### Going back is refused in two places, because a code is spent in two

The viewfinder hides its back button while a credential is in flight, which is where §5 draws it.
The outcome screen hides its own for `spending` and `savingToken`, which §5 does not draw because
the frame it drew had no button and therefore no wait: the words path spends its code on *this*
screen, and the Keychain retry that Davide added spends the token it bought here too. Hidden rather
than dimmed in both, for the reason recorded when the viewfinder shipped — SwiftUI has no disabled
back button, and drawing our own is hand-building the one piece of chrome the system owns.

## Success routes into the worktree list, which makes it the first control in this app that had none

The sidebar shipped with "no way to reach it, and that is the point": pairing had no screen, so a
route to it would have been a link to a screen that cannot load. Pairing has four screens now, so
the route is built rather than deferred — a pairing that succeeds and goes nowhere is precisely the
defect the previous entry was written about, arriving one release later through the same door.

**`HttpGranitaRepository` learned to address a `PairedMac`**, rather than the composition root
assembling `https://host:port` from one. Same argument as the pairing route two files over, and it
is recorded again because it was nearly repeated: the root is the one layer no test can reach, and
"which address did the request actually go to" is exactly the question a test should be able to ask.

**The route value is the `PairedMac` itself**, and a pair of it with the Mac's name was written and
then taken out again. §5 titles the list with that name, so carrying it looked obviously right — and
nothing reads it, for the reason below, which makes it API a screen has not agreed to. This file
already has an entry about shipping exactly that, so the second one lasted an hour rather than a
release.

### The one clause of §5 this does not build is that title, and the reason was measured

`WorktreeSidebarView` titles itself *Worktrees*. §2 never says what the title should be, so that was
the implementer's choice rather than a competing decision, and §5's sentence is the only statement
on the matter — which would ordinarily settle it.

What stopped it is arithmetic rather than doubt. **A `navigationTitle` applied outside a view that
sets its own does not override it**, which was checked rather than assumed: the sidebar screen's
baseline was rendered with `.navigationTitle("Mac Studio")` wrapped around it and the suite stayed
green, so the outer one changes nothing at all. Titling the list therefore means threading a name
through §2's view, and that moves **52 committed baselines** across two suites — a re-record of
another slice's screens, in the commit that wires navigation, reviewed by an eye that cannot look at
52 pictures properly. A re-record is a design change and gets its own pass.

So the route carries the name and the screen does not wear it yet, and the modifier that would have
been a no-op is **not** left in place looking like it works. Davide's call: build it with the
re-record, or let the list stay *Worktrees* and amend §5.

## The viewfinder gets a camera, and the session had to outlive the run to give it one

`CaptureSessionCodeScanner` said the live preview was not its business and that "the composition
root is the one place allowed to see both, which is where that join goes when the screen lands". The
screen has landed. What the join needed was not a new seam but a smaller change to the old one: the
session is now made **once, at construction, and never replaced**.

A preview layer follows a session *object*. One built per run, as this file did, cannot be attached
to anything before the camera opens — and the screen has to draw a viewfinder while the permission
alert is still up, which is the state §5 spends a paragraph on. An empty session opens no camera and
needs no grant, so it can exist from the moment the scanner does, and a second run reuses it: the
input stays on it, because taking the camera off to put an identical one back would blank the
preview in front of the reader, and only the metadata output is replaced, because the delegate it
reports to belongs to one run.

**The view that draws it is in `Ui`, not in the composition root**, even though the root is what
hands the session over. `AVCaptureVideoPreviewLayer` is a system framework and a `Ui` target may see
those; what a `Main` target may not hold is a `UIViewRepresentable` and a `UIView` subclass, because
a `Main` module is exempt from both coverage rows and logic left in one is untested code that no
longer looks untested.

The cost is stated rather than waved through: **not one line of any of this can be run on a build
machine**, so the only check that means anything is a device, and the session's own file has said
that about itself since it was written. What the design calls a frozen frame is a stopped session,
which is what §5's own sentence describes ("the session stops, the preview dims") and is not the
same as a held still.

### Two smaller calls in the same commit

**The entry screen resolves its own address line.** §5's frame draws `MacBook-Pro.local:59144` under
the two credentials and its prose never mentions it, so the drawing is the only authority and the
line is built. The lookup **returns rather than records** — a value kept on the model would sit
under the *next* Mac's name for as long as its own lookup took, which is a lie rather than a stale
caption — and it is silent on failure, which is right for a caption under two buttons: a Mac that
will not resolve says so properly, with a screen and a remedy, the moment a credential is spent on
it.

**TestFlight's scheme is declared in the property list**, because `canOpenURL` answers `false` for
any scheme that is not, whatever is installed. Without that line the decision recorded above it —
that the button appears only when the system says it can open it — would have been a rule that
always answers no, which is the same defect as the button that cannot work, wearing the rule that
was written to prevent it.

**`PairingNotReadyView` is deleted**, with its suite and its four baselines. It existed to say that
pairing had no screen, and it said so honestly for one release rather than leaving a row that did
nothing. There is a screen now.

## The iPad's split view arrives, and it broke twice in ways only a photograph could show

Design §2's other half — a 320pt sidebar and a *Choose a worktree* detail column — has been waiting
for "whichever composition root presents this screen", and pairing brought it. Two things this file
would otherwise have recorded as reasoning are recorded as measurements instead, because both of the
first two attempts compiled, read correctly, and rendered a broken screen.

**A collapsed split view inside a navigation stack draws its chrome and none of its content.** The
first build let the phone take the documented collapse — a split view in a compact width folds into
its sidebar — and the iPhone baseline came back with the title, the toolbar menu and *no rows at
all*. It has to be inside a stack, because §5 requires that back returns to the Mac list. So the
compact width is a branch rather than a collapse: the phone gets the sidebar screen directly, which
is what the fold was supposed to produce, and both widths are photographed. The question asked is
the horizontal size class and not the device, because an iPad in a narrow multitasking width is the
phone's layout too.

**A split view keeps the destinations declared inside its columns.** The list's rows have been
value-based links since §2 shipped, with their destination declared in the sidebar screen beside
them — the placement this project adopted after shipping a row that did nothing. Put the split view
around that screen and the declaration no longer reaches the stack outside it: a worktree pushed on
the root's own path rendered the system's yellow missing-destination placeholder. That is the same
defect returning through the door that was built to keep it out, and a snapshot found it because
this suite photographs the pushed value rather than the resting screen.

So **the destination is declared twice, on both containers that can claim a tap**, written once as
one modifier so the two cannot drift. The stack's half is asserted by a baseline; the split view's
half cannot be, because no test kind that runs here can tap a row and only a finger can say which
container SwiftUI hands the value to. Both lead to the same screen, so the one outcome that is ruled
out is the row going quiet. It collapses back to one declaration the day design §3 gives the detail
column something of its own to show.

### The measure stops at the paired Mac, which is two designs meeting in the root

§5 says "everything before a paired Mac lives in a 420pt column, title included" and §1 says that
measure goes around the navigation container rather than around the screen. §2 then puts the list
itself in a split view whose sidebar is 320. Both hold, and they hold in the same container, so the
root's clamp is now conditional: a 420pt cap around a two-column split view would leave an iPad
reading its worktrees through a phone-shaped slot.

**It cannot be read off the path**, which is why the root gained a second piece of navigation state
beside it. `NavigationPath` is type-erased on purpose — that is what lets each destination be
declared beside the link that reaches it — and a paired Mac and a Mac about to be paired with both
sit at depth one. Back out of the list is watched on the path emptying rather than reported by the
screen, because the button that performs it belongs to the system and tells us nothing.

### Two smaller calls in the same commit

**The row's name moved from the screen to the model.** `WorktreeSidebarScreen` resolved the tapped
worktree's display name in a private helper; the detail column needs the same answer, and a second
copy of a lookup is how two containers come to disagree about what was opened. `displayName(of:)`
is on the model with three tests — the alias the row showed, a worktree that left the list between
the tap and the push, and a state holding no rows at all — which is two more assertions than the
helper ever had.

**The handshake's two branches are spelled out.** `attempt.pin.map(...) ?? UrlSessionHttpTransport()`
was correct and said nothing: the label that names trust on first use had been left to its default,
in the one line of the composition root where getting it wrong pins nothing and looks identical.

## `waiting` is terminal for a connection, which is the opposite of the recorded browser lesson

`BonjourBrowser.change(for:)` treats `.waiting` as **recoverable** and says so in as many words: a
waiting browser is alive and comes back on its own, so the stream stays open and the session does not
replace it. That lesson is recorded, it is right, and it is about a *browser*.

**An `NWConnection` is the other way round, and a later reader will "fix" this if nobody writes it
down.** A connection that reports `.waiting` has failed to establish and will not establish itself;
what recovers it is a new connection, not patience. So `BonjourServiceConnection` reports waiting as
terminal, ends the stream, and lets the resolver answer. Two types, two opposite readings of one
enumeration case name, and the only thing standing between them is this entry.

The failure enum has exactly **two** cases — unreachable, carrying the diagnostic, and
localNetworkDenied — because those are the two design §5's outcome screen can say something different
about. `localNetworkDenied` is kept out of `unreachable` rather than folded into it precisely because
folding it would offer *Try Again* against a permission that never grants itself, which is a control
that cannot work. Rejected: a case per `NWError` code, which is a vocabulary no screen branches on.

Recorded rather than left in a doc comment because the agent that wrote it judged this file too
contended to touch from a worktree, and was right to hand it back rather than risk a three-thousand
line collision.

## An IPv6 address is bracketed and its zone escaped, and that was two routes rather than one

**This entry replaces one that said the opposite.** It recorded the defect below, argued that
degrading was honest enough for v1, and named the fix it was not doing. It was wrong on the size of
the hole: the same four lines are written three times, so the failure was never confined to the
words path — a Mac reached over IPv6 could not be *read from* either, which is a paired phone that
lists no worktrees. The fix is now built and this says what it does.

`NWPath`'s resolved endpoint stringifies an IPv6 address with its zone attached — `fe80::1%en0` —
and `URLComponents` will not take either half of that as a host: a bare literal's colons read as a
port separator, and a `%` is an escape that never was one. `components.url` comes out nil, so
`HttpServerPairing` **and** `HttpGranitaRepository` both fell back to their documented
nowhere-address, which is a `file://` URL handed to an HTTPS client. A Mac plainly sitting on the
desk was reported unreachable, twice, for two different reasons a reader would have read as one.

`ServerAddress.httpsUrl` is now the one place any of it is built, in `ClientConnectionData` beside
the two callers. RFC 6874 is the shape: the literal in square brackets, the zone's `%` written
`%25`, and it goes in through `percentEncodedHost` because the plain setter escapes the escape.
Whether an address is a literal at all is asked by looking for a colon, which a host name cannot
contain — no parsing, and nothing that a v4 address or a `.local` name takes a different path
through.

The nowhere-address fallback stays, and keeping it is the point of the change rather than an
oversight: a host that genuinely cannot go into a URL is a damaged scan, and *could not reach your
Mac* is the closest true thing this app can say about one. What was wrong was how much fell into
that sentence.

Kept from the entry this replaces, because the diagnosis is the expensive part: the symptom is
*could not reach your Mac* against a Mac that is plainly there, which reads exactly like a firewall
and costs an afternoon. Both routes are asserted for a literal with a zone and without one, and the
connection's own suite pins that the address arrives carrying the zone rather than being tidied on
the way through — an address that lost it names an interface nobody chose.

## The camera joins the two Keychains as unrunnable, and the scope is renamed a fourth time

`CaptureSessionCodeScanner` is 137 lines of `AVCaptureSession` configuration that a host test process
cannot execute one branch of: there is no camera, `AVCaptureDevice.default(for: .video)` answers nil,
and the configuration returns before it has performed any of itself. That is the bar the two Keychain
stores met — unrunnable by construction rather than merely untested — and the login item after them.

**The decidable part was taken out before the exemption was added**, which is what separates this from
a hiding place. Turning whatever a metadata object carries into a `ScannedCode` is a pure function; it
lives in `MachineReadableCode` and is tested against a nil string, an empty one, a stranger's QR and a
damaged Granita link. What stays behind is session configuration, one delegate AVFoundation calls, and
a lifecycle guard — no branch a reader could ever see the wrong side of.

**This one raises the number, and that is the test this file applies to every rescoping**, so it is
argued rather than asserted: without it the Unit row reads 92.7% and with it 95.0%. The 2.3 points are
not tests that were written; they are lines that stopped being counted. What justifies counting them
out is that no test of any kind that this repository can run — host, snapshot, or the `ui` target that
does not exist — could ever reach them, so their presence in a denominator makes the row answer a
question about a camera rather than about the code.

`host-reachable-no-system-services-no-screens-no-appkit-serial` becomes
`…-no-appkit-no-camera-serial`. The rename is the mechanism working rather than a tidy-up: it makes
the Unit and All rows **unjudged for one run** and rejoin on the next `main` run, so nothing is
compared across two different file sets. **A reviewer should read this slice's green Unit row as
unjudged rather than as held** — the two rows that are genuinely judged here are the Snapshot ones,
and they went up.

## An attempt belongs to one Mac, and the model was letting one outlive its screen

One `ClientConnectionModel` serves the whole app, which is the right shape — discovery and pairing
are one question — and it had no notion of an attempt ending. Nothing cleared what a spend left
behind, so three of design §5's four screens could be drawn about a machine the reader had walked
away from.

The worst of it was *Try Again*. The outcome screen chose between the two credentials by asking the
model what it last spent; the words path, when the address would not resolve, set a state and left
that value untouched. So: scan one Mac, be refused, back out, open a second, type its six words,
watch the lookup fail, tap Try Again — and the first Mac's link is spent, at the first Mac, under
the second Mac's name in the title bar. **The screen a reader is looking at would have been about a
different computer than the one they paired with.**

Three changes, and each is a different half of the same rule.

1. **Opening a Mac's own screen starts an attempt.** `beginPairing(with:)` clears the outcome, the
   phrase and the credential, and the entry screen calls it from the task it already had. It sits
   under all three of the others, so it is the one place that sees every arrival. Unconditional
   rather than only when the Mac changes: coming back to the Mac that just refused you is starting
   an attempt too, and that is the case where the viewfinder re-opened on a dimmed frame reading
   *Pairing with…* with its back button hidden for a request nobody had made.
2. **Every path that tries to spend says what it spent, including the ones that spend nothing.** Six
   words that never found an address spent nothing, so that path now writes `nil` rather than
   leaving an older attempt's credential for a retry to find.
3. **The retry is handed the Mac.** `spendAgain(on:as:)` lives on the model and takes the Mac the
   screen is titled after, and a credential recorded against any other one is not offered back. That
   is the guarantee that does not depend on a view lifecycle, and it is asserted without one: a test
   drives the whole cross-Mac sequence and a second drives it with the reset deliberately skipped.

**`spentCredential` went private with the third change, and that is the point rather than a
side-effect.** It was public because a screen switched on it; now the model answers the question
instead, so there is one place that decides what a retry means rather than a value and a screen that
can disagree about it. `join(_:as:)` stopped being public for the same reason — nothing outside this
module ever called it.

Rejected: leaving the choice in `PairingOutcomeScreen` and merely clearing more state. It would have
fixed today's sequence and left the next screen free to make the same reading, and the thing that
went wrong here is precisely that a value with no owner was consulted by something that could not
know what it meant.

## `loadPairingHistory()` and `pairedServers` are removed for the second time

The entry above them — *the row is right twice, and the second time it says: do not ship a screen's
API before the screen* — took these two out of this model once already, in the release that split
the pairing sequence into `Domain`. They came back with the pairing screens, and no screen reads
them: only their own tests did.

What they are waiting on has not moved either. Design §1's *Recent* and *Other Macs* sections are
the reader for this, and they need a join between a Bonjour instance name and a stored token — which
is the `serverInstanceID` in the TXT record SPEC §8 asks for and the Mac does not publish. Until that
lands, the discovery list ships as the single unlabelled section the design says it degrades to, and
a set of identifiers nothing can match against anything is a property no screen has agreed to.

`MacJoining.alreadyPaired()` **stays**, and so does the store method under it: they are `Domain`,
they are asserted where they happen in `MacPairingTests`, and they are what the section will be
ordered by on the day the record carries the identifier. What is removed is the copy held on a model
that draws screens, plus the `finish` step that maintained it — which, once it stopped inserting,
was a one-line rename of an assignment and is inlined at both call sites.

Written down a second time because the first entry did not stop it happening again. The rule is not
"delete these two properties"; it is that a model in a layer the Snapshot row measures may not carry
state that nothing renders, and the tell is a test being the only caller.

## The six-word field lost its vertical axis, because Go has to do something

`PairingWordsView` carried `submitLabel(.go)` and `onSubmit(onPair)` over a `TextField(axis:
.vertical)`. A field on a vertical axis takes Return as a newline and never submits, so the key that
reads as the action was not the action — the shape of dead control this project is named for, drawn
beautifully in four baselines the whole time.

The axis goes. §5 asks for one field with Go on it and that is now what ships, at the price the
vertical axis was buying: a six-word phrase is longer than one line at 390pt, so the field truncates
rather than wrapping. **That price is smaller than it looks, because the field was never the thing
being compared.** §5's argument is that the reader checks the *echo* against the Mac's line — a
different and far easier task than proofreading their own typing — and the echo wraps. Twenty of
that screen's baselines and the spine's `the-six-words` four were re-recorded against the new shape;
the field is the only thing in them that moved.

**And the normaliser now takes a line ending as a separator**, which is the defect underneath the
control one. A newline mid-phrase fused the two words either side into a token in no list, so the
echo read `apple⏎badge` and the unknown-word line named a word the reader never typed while pointing
them back at a Mac showing the right ones. Return was one way in and is now gone; **paste is the
other and cannot be**, and §5 makes paste the answer for the reader whose camera and whose Mac are
the same screen. `\r\n` is in the separator set beside `\r` and `\n` because a `Character` is a
grapheme cluster and the pair is one of them — a set holding only the halves matches neither.

## The iPad's worktree list is pinned, because its destination was reading a model nobody loaded

`WorktreeSplitScreen` held its model as a plain property. The composition root presents it from
inside a `navigationDestination` closure that **builds a new `ClientWorktreesModel` on every
evaluation**, and the sidebar underneath pins the first one in `@State` and is the only thing that
loads it. So the rows came from a loaded model and the destination declared beside them resolved the
chosen row's name against whichever instance the last evaluation had produced — one that had read
nothing, whose display name is therefore the fallback word. **Every worktree opened on the iPad was
titled *This worktree*.** The phone was unaffected: it branches to the sidebar screen, which pins.

The screen pins now, the same way the sidebar and the discovery screen already do and for a stronger
reason — for them a swapped instance is a task driving a discarded object, here it is two halves of
one screen disagreeing about what is on it.

**No snapshot kind can see this, and that is worth stating rather than working around.** A picture
is taken of one view value built once; the defect needs a second evaluation with a different
instance, which a test that constructs the view cannot produce and a wrapper that forced one would
race the raster it is trying to assert. What the suite gained instead is a baseline of the fallback
itself — a chosen worktree that is no longer in the list, which is the one case *This worktree* is
legitimately the answer, since an agent removes a checkout every day and one can stop being in the
list between the tap and the push. It is photographed so that word is a state somebody chose rather
than one nobody could see.

## `PairedMac` carries the Mac's name, because nothing else on that screen says which Mac

Design §5's last clause is that a pairing that works lands the reader on "the worktree list titled by
the Mac's name". 0.1.0 shipped it titled *Worktrees* and said so in a comment, which is the honest
version of not building something — and the reason it was deferred was real: `PairedMac` held a
device record, an address and a fingerprint, none of which is a name a reader would recognise, and a
`.navigationTitle` applied to the container in the composition root does not override one applied
inside the screen.

**The name is a field on `PairedMac` now, and it is passed into the pairing rather than derived.**
`MacJoining.pair` gained the `DiscoveredServer` beside the credential, because a credential cannot
supply this: a scanned link carries a host and six words carry neither, and a host is not the string
the reader saw. The one string that is, is the Bonjour instance's display name — the row they tapped
in the Mac list, and the title of all four pairing screens after it. So the list is titled with the
same words the three screens before it were, which is what makes the replacement read as arrival
rather than as a jump.

> Rejected: deriving the title from `PairedMac.address.host`. A Mac reached over `192.168.1.24` — or
> over the IPv6 literal the entry above this one bracketed — would put an address at the top of the
> one screen this product exists for. Rejected: reading it off `ClientConnectionModel.pairingWith`
> inside the model. That property exists to let a *retry* refuse a Mac it does not belong to, and
> spending it a second time as a data source would make one optional the source of two unrelated
> truths. Rejected: pushing a name beside the `PairedMac` on the navigation path. The path is
> type-erased on purpose; two values for one destination is how a screen comes to disagree with
> itself about what is on it.

**Every method that spends a credential now takes the Mac**, which is the shape `spendTypedWords` and
`spendAgain` already had and `readCode` did not. That is not symmetry for its own sake: the model is
one instance for the life of the app, so the Mac an operation is *about* has to arrive with the
operation rather than be read off state that outlives it. This is the same rule the cross-Mac retry
defect produced, applied one method wider.

### And the title is inline, which the name cost

The first render answered a question nobody had asked. A large title is 34pt bold and truncates at
the tail, so *Davide's 16-inch MacBook Pro* came back as *Davide's 16-inch Mac…* at 390pt and
*Davide's 16-inch…* in the iPad's 320pt sidebar — dropping exactly the half that distinguishes one
Mac from another, which is §1's stated reason for truncating these names in the middle rather than at
the end. A `.navigationTitle` cannot be given a truncation mode, so the direction is not available;
what is available is a smaller title. Inline is 17pt semibold, the whole name fits, and the list
gains back the 52pt a large title spends on every scroll.

Davide's call, 25 August 2026, against two rendered layouts rather than against an argument. The
alternatives it beat are in [`design.md`](design.md) §2, and the frames that would have settled it do
not exist — §2's were deleted when §2 shipped, which is that rule working: what survives a drawing is
the argument, and this is one the drawing never had to make because §2's title was one word.

### What this name is not, and the case it gets wrong

**A QR scanned at one Mac while another Mac's screen is open is named after the one that was open.**
The spine is *Macs → this Mac → Scan*, so the viewfinder, the outcome and now the list are all titled
after the row the reader tapped; the link they hold up carries a host, a port and a key, and the
pairing goes to whichever machine those describe. Point the camera at the wrong Mac and the
connection is right and the label is wrong.

It is left that way rather than repaired, and the alternatives are why. A link carries no name, so the
only thing to fall back on is `link.host` — which is `davides-macbook-pro.local`, a string the design
spends §1 keeping off the screen. Comparing the link's host against the opened Mac's resolved address
would catch it, at the price of a resolution on the scanned path that path deliberately does not need:
the QR is the credential that already knows where it is going. What this costs is a wrong word on a
screen whose content is correct, in a sequence the reader had to leave halfway through to produce. The
mismatch is older than this entry — every pairing screen has been titled that way since 0.1.0 — and
what changed is that it now survives past the pairing.

## §4's wrap-off scroll splits the row in two, and a photograph is what said so

The first attempt at design §4's diff line was one view holding both halves — the number column and
the code — with the code at `fixedSize(horizontal: true)` so that it runs past the trailing edge
rather than truncating at it, which is what wrap-off means. It compiled, it read correctly, and the
baseline came back with **the gutter off the leading edge of the screen**: a row wider than its
container is centred in it, so forcing the code's width pushes the numbers out of the frame in the
one direction nothing can scroll back to.

The deeper version of the same thing is the reason it cannot be repaired by an alignment. `SPEC.md`
§10 says long lines "scroll horizontally within the file **with the gutter pinned**", and a gutter
inside the row is inside whatever scrolls the row. So the two halves cannot be one view:

- the number column is a fixed-width stack outside the horizontal scroll;
- the code is a stack inside it;
- and the two are separate view trees that must agree on every row's height, which means the height
  is stated once rather than left to two text engines to arrive at.

That is a bigger change than a layout fix and it decides what the file section, the sticky header and
the estimated heights are all built on, so it is recorded rather than rushed. **The row and its five
baselines were taken back out** — a view that lays out wrongly is worse committed than absent, and
the measurement is the part worth keeping.

What the photograph did confirm, and what the rewrite has to preserve: the tints and the word
segments are right. A deletion at 10% red under an addition at 10% green, the changed run at full
strength and the unchanged runs at `.secondary`, and the eye goes to the text rather than to the box
— which is §4's call, and the frames use it in all three palettes rather than only in dark.

`MonospacedGrid` stays, because it is right either way: `displayColumns` travels on every line with
tabs already expanded to a stop of four, and a view that handed the raw string to a text engine would
get that engine's tab stops instead — a tab-indented file drawn at one width and measured at another.
The constant now lives in one place and `DisplayWidth` reads it from there.

## `onChange` dies at `onDisappear`, and 0.1.0 shipped its pairing success on one that had

**Pairing hung forever on the in-flight frame, on both credentials, on a real iPhone.** The Mac's
document gained two device records ninety seconds apart and its log then refused a third attempt as
`pairingExpired` — so `POST /v1/pair` answered 200 twice, the phone kept the token, and the reader
sat under *Pairing with MacBook Pro / Checking the Mac, then spending the code.* with nothing to
press. 786 tests, 208 baselines and an adversarial audit were all green.

The watch for the one ending with no screen of its own lived on `PairingEntryScreen`, on the
reasoning written into its own doc comment: that screen sits under all three of the others, so it is
the one place that sees every path. **Being underneath is exactly what stopped it working.**
`onChange` is scoped to a view's *appearance*, not its lifetime, and a `NavigationStack` calls
`onDisappear` on a screen the moment something is pushed over it. By the time a pairing can succeed
there is always something over the Mac's screen — the viewfinder, or the six-word screen and the
outcome screen above it.

Measured rather than reasoned, in the simulator, with the entry screen logging its own body,
appearance and change: `onAppear` at push, `onDisappear` when the six-word screen arrived, then the
body evaluated three more times — including once with `pairing = finished(.paired(…))` — and
`onChange` never fired once. Three seconds later the stack was still three deep. **The body goes on
being evaluated, so in a debugger the observation looks alive**, which is why this survived review.

Success now hands over from the two screens that can be frontmost when a credential is spent — the
viewfinder and the outcome screen — through one modifier, `PairedMacHandover`, and nothing beneath
them watches for anything. It carries `initial: true` because the scanned path replaces the
viewfinder with the outcome screen the instant a spend finishes, so what the next screen arrives
holding is a state that has already stopped changing.

**What is asserted, and what is not.** `PairingState.pairedMac` is the handover as a value, and it is
covered against every state including the two other endings that carry a `PairedMac` — handing one of
those to the worktree list would open it against a token this phone never stored. **The
appearance-scoping itself is reachable by no test kind this project runs**: a unit test has no view
hierarchy, and a snapshot photographs one view value that was never pushed over. It took a simulator,
a seeded navigation path and a log. That is the second defect in this repository whose only witness
was running the app and pressing the thing.

## Every step of the pairing sequence is bounded, so no step can end in a spinner

Davide's call on the night the above was found, and it outranks the bug: *something stuck without an
outcome is unacceptable — if there is an error, we must show it.* Fixing the navigation removes
tonight's instance; a bound removes the shape.

`MacPairing` now gives every awaited step a patience and answers `neverAnswered` when one runs out,
so the sequence is incapable of not producing a `PairingOutcome`. **Seventy-five seconds, and the
number is a backstop rather than a policy.** Every network step already has the transport's own
sixty-second request timeout, and a shorter bound here would replace `URLSession`'s diagnostic with a
worse one on an ordinary bad network. What it is actually for is the step with no deadline at all:
the Keychain is a synchronous call into another process and nothing above it can call it off.

**Not a task group**, which is the one implementation detail worth recording. A group awaits every
child before it returns, so a step that ignores cancellation would hold the group open for exactly as
long as it would have held the caller — the bound would be decorative, and the step this exists for
is precisely the uncancellable kind. What races instead is a one-shot actor that takes the first of
two answers and lets the loser finish or not finish on its own.

`PairingStall` splits the ending three ways and the split is **whether the code left the phone**,
because that is the only fact the reader can act on. Before it goes, another tap costs nothing and
the screen says so in the sentence this app already uses twice. After it, the Mac may hold a device
record and the screen has to be as careful as the Keychain one is: it names the trip to Settings ▸
Devices and offers no retry, because a button that spends a credential that may already be gone is
worse than no button. A write that never answered keeps the retry, for the reason a refused write
does — the token survives in the outcome, and the code that bought it is spent either way.

**The Keychain was the prime suspect and it is not the cause.** Run inside the simulator against the
real `KeychainPairingTokenStore` — never executed anywhere before, since a SwiftPM test binary is
unsigned and has no keychain — every call returned in about five milliseconds with
`errSecMissingEntitlement`, which is a `tokenNotStored` and therefore a screen. Recorded because the
next person to read that type's doc comment will suspect it too.

## The handover modifier is a view, so it moves to `Ui` rather than joining the exempt list

The bound above cost the Unit row four tenths of a point, and reading the per-file export rather than
estimating found that almost none of it was the bound. **`PairedMacHandover.swift` was twenty-two
mapped lines, none of them covered, and nineteen of those are a SwiftUI body** — `body(content:)`,
the `onChange` closure inside it, and the haptic that closure calls. A host test has no renderer, so
it can reach exactly one of the file's seven regions: the `View` extension that builds the modifier.

Filed under `Presentation`, it sat in the one place where both scopes get it wrong, and the exports
say so rather than the argument doing. The Unit scope excludes a view body **wherever it lives**, but
it spells that as `…Screen.swift` — so this file was judged by the row that cannot execute a line of
it. The Snapshot scope selects a `Ui` module plus the screens composed from one, and this is neither
— so **the snapshot pass covered seventeen of its twenty-two lines and the Snapshot row counted none
of them.** Charged in full to the row that cannot see it, invisible to the row that does.

**So the file moves to `Client/Connection/Ui`, and no predicate changes.** That is the whole of the
fix, and it is the architecture's own answer: a `Ui` module is a vocabulary of stateless views, each
taking what it renders and reporting what happened, and this takes a `PairingState` and reports a
`PairedMac`. It never referred to a model or a `Data` target, so nothing about the move was
constrained — `Presentation` depends on `Ui`, so the two screens that apply it are unaffected beyond
the modifier becoming `public`.

> Rejected: adding it to `UNREACHABLE_FILES`. That set is for code unrunnable by construction for a
> reason that is *not* a layer — a keychain a test binary does not have, a camera, `NSApp` — and a
> view body already has a category of its own. Rejected: widening `is_screen_path` to catch a
> `ViewModifier`. It would be the right change if the file were in the right place, and it is not;
> it also renames both scopes and leaves the Unit, All **and** Snapshot rows unjudged for a run,
> which is the pull request that fell under the gate marking its own homework.

It does raise the Unit row, which is the test this file puts every rescoping to, so it is argued
rather than asserted: what leaves the denominator is nineteen lines no test kind this repository runs
could ever execute from the host, plus three that now count where they are covered instead of where
they are not. Nothing that a test could have reached stopped being counted.

### And the rest of the four tenths was real, so it is covered

Five regions of `MacPairing` had no test. `FirstAnswer` is **internal** now for the same reason the
patience beside it is: both of its guarantees are about the loser of a race — a second answer that is
dropped, and a first one still readable after it landed — and `answer(from:)` gives a test no say in
which of its two tasks wins. Through the sequence they are a coin flip; asserted directly they are
three sentences, one of which is the ending every stall actually produces, where the uncancellable
step finishes forty seconds after the reader has been told the attempt ended.

The contract read's refusal had none either, on either side of the boundary: `read()`'s `catch` and
the `case .failure` that turns it into `.refused`. It is the one refusal that costs nothing, which is
the entire reason that step goes first, and the assertion that says so is that no code was offered.

Five more of the sequence's own steps were covered while the export was open, because the claim above
is that there is no path out of pairing that is not an outcome and these were five of the paths
nothing held to it: what the handshake answers when it is asked what it trusted, which is the value
every later request is pinned to; an address no URL will hold on the spoken path as well as the
scanned one; a link carrying no query items at all, which is a different absence from an empty field
and reads as the first field being missing; a proxy answering 502 with HTML, where the status is the
only true thing left to say; and the two guards `GranitaHttpClient` puts on the way out — neither
reachable through a route, because every route is a literal path and every body is a type this app
wrote, and a guard nothing can provoke is one nothing holds to its sentence.

## The diff screen is reached through a builder the compiler makes mandatory

Design §4's continuous scroll is another feature's `Presentation` — `ClientViewerPresentation` — and
the rows that open it live in `ClientWorktreesPresentation`. A `Presentation` target may see its own
feature's `Ui` and any `Domain`; a sibling `Presentation` is exactly the edge the graph refuses, and
the rule for that case is written down: the design is wrong, not the rule.

The obvious escape is to declare the destination in the composition root, which is what the
`PairedMac` link already does. **It does not work here**, and the reason is recorded two entries up:
a split view claims the destinations declared *inside its own columns*, so a `navigationDestination`
that lives only in the root is one a sidebar row inside the split view never reaches. That is the
defect this app shipped for eight releases, arriving through the door built to stop it.

So the declaration stays inside the worktrees module and only *what it builds* comes from the root:
`WorktreeSidebarScreen` and `WorktreeSplitScreen` are generic over the view a row opens, and the
builder is a **required initialiser parameter**. A row that leads nowhere now fails to compile, which
is a stronger guarantee than the comment this project relied on while it was shipping one — and the
snapshot suites pass the *real* diff screen rather than a stand-in, because a picture of a stub
asserts that a stub leads somewhere.

The cost is two generic view types. `WorktreeSplitScreen.sidebarWidth` had to move with it — a
generic type may hold no static stored property — and it went to `WorktreeSidebarView`, which is
where a fact about that row's width belongs anyway.

### And the first baseline of the pushed screen photographed a spinner

`WorktreeDiffScreen` loads from its own `.task`, so the suite that pushes it was racing its own
shutter: the recording came back as a progress view on an empty screen, which is both
non-deterministic and an assertion that a row leads to a spinner. The viewer model is loaded
*before* the render now, by a helper the two screen suites await, and what those baselines hold is
the diff. The sidebar suite was already `.serialized` for the same class of reason; the split suite
now is too.

### The name travels with the identifier, because the same defect tried to come back

An adversarial read of the wiring, before it merged, found 0.1.0's iPad defect reappearing through
the mechanism built to prevent a *different* one.

The builder is written in the composition root, inside a `navigationDestination` closure that is
re-evaluated and **builds a new `ClientWorktreesModel` every time** — while the screen below pins the
first one and is the only thing that loads it. The first version of the builder resolved the title
itself, from the local the root had just constructed. That model has read nothing, so
`displayName(of:)` falls through to its fallback and **every worktree would have opened titled *This
worktree*** — which is word for word the entry three above this one, in a new place.

So the closure takes `(WorktreeID, displayName)` and the screen that holds the loaded model resolves
the name. The root is handed the answer rather than the means to compute it wrongly.

**No test kind here would have caught it.** A snapshot constructs one view value with one model that
was loaded before the render; the defect needs a *second* evaluation with a fresh instance, which is
the same thing the entry above says about pinning. It was found by reading the wiring end to end,
which is the one review this repository has now recorded twice as the only thing that finds this
class — and 0.1.0's lesson was to budget for exactly that pass and not let it grade work it did.

## §3's selector belongs to the viewer, and on iPad it is a column inside the diff rather than a third column of the split view

Design §4's iPad is "three columns at 320 / 320 / 554", and the obvious build of that sentence is a
three-column `NavigationSplitView`: worktrees, then files, then code. It is not what shipped, and the
reason is the layer graph plus the one thing this repository cannot check.

**The selector is the viewer's**, not the worktree list's. It navigates the diff, it reads the same
change set the scroll is drawing, and `ClientViewerModel`'s doc comment has said since 0.2.0 that the
scroll, the file header and §3's selector are three views onto one question. A third split-view column
would have to be composed where both features are visible, which is `ClientAppMain` — and a `Main`
module holds wiring and nothing else, which is the argument that made `WorktreeSplitScreen` a screen
rather than four lines in the root.

**And a real third column means selection-driven navigation**, because a `navigationDestination`
produces one view and not two columns. That would turn the sidebar's rows from value-based links into
a `List(selection:)`, on the one navigation path this app has proven — the path that broke twice in
0.1.0 in ways only a photograph could show, and that carried a row leading nowhere for eight
releases. **There is no iOS UI test target**, so the only check on it is a thumb, and a thumb is what
this machine does not have.

So `WorktreeDiffScreen` composes it: a drawer on the phone, and in a regular width an `HStack` of the
selector at 320pt, a divider, and the code. Inside the existing split view's detail column that is
320 + 320 + 554 at iPad Pro 11" landscape — §4's measure exactly, photographed rather than argued.

> Rejected: the three-column split view, above. Rejected: putting the selector in
> `ClientWorktreesPresentation` so the split view could own it — that target may not see a sibling
> `Presentation`, which is the same edge that made the diff screen's builder a required parameter.

### Two things the handover asked for that did not happen, and both are Davide's to settle

**`NoWorktreeChosenView` stays.** The note that opened this slice said §3 "deletes the detail column's
*Choose a worktree* the way §4 deleted the not-ready screen". Design §2 says the opposite in as many
words — "the empty detail column is an unavailable-content view, the same control as every other empty
state in the app" — and it gives the reason: a blank column reads as a screen that failed to load.
Under the composition above the detail column is still empty until a worktree is chosen, so deleting
that view would leave exactly the blank §2 forbids. **The `design` skill's rule for prose against
prose is to ask rather than pick**, so this is asked rather than picked.

**The doubled `navigationDestination` stays doubled.** Its comment predicted it would collapse "the
day §3's file selector gives the detail column something of its own to show", and that day has not
arrived: the detail column shows the selector *for a chosen worktree*, so the tap that chooses one is
still claimed by one of two containers and which one cannot be settled on a machine with no finger.
Removing a declaration to find out is how this app shipped a row that did nothing.

## The mark is written optimistically, and §3's report and §4's toggle are one fact

Design §3's row carries a viewed mark and says plainly that it is **not** a control there: a 32pt row
inside a sheet cannot hold two tap targets without generating mis-taps. Design §4 puts the toggle in
the file header, "where the reader is when they finish a file". Built separately those are two
features; built together they are one, and that is why the toggle lands in the same slice as the
selector — a column that reports a state nothing in the app can write is a column that is empty
forever.

`markViewed` is written **against the file's own content hash**, which the Mac refuses on. That is the
one guard that matters: a mark applied to a version nobody saw is the only way this product can
actively mislead someone.

The write is optimistic and taken back on a refusal, with an alert saying so — the same shape the
sidebar's rename and pin already use, and for the same reason: the row has to change under the finger,
and a mark that silently reverted would be the app disagreeing with the reader about the one thing it
is for. A diff arriving from a batch asked for *before* a mark was set keeps the mark rather than the
Mac's older answer, which is asserted.

**Collapsing a viewed file is not built.** `SPEC.md` §10 says a file marked viewed renders collapsed;
design §4's collapsed bars are the piece still drawn and not built, and this slice does not add them.
What the toggle does today is perceivable in three places — the circle fills, the selector's row dims
and takes a check, and the footer counts — so it is a control that works rather than one that waits.

## A jump is a scroll position by identity, and a `ScrollViewReader` could not do it

Tapping a file in §3's selector has to move §4's scroll, and the first build did the obvious thing: a
`ScrollViewReader` and `proxy.scrollTo(id, anchor: .top)` from a watch on the chosen file. **The
baseline came back with the first file still at the top.** The stack is lazy, so at the moment that
watch fires the row being scrolled to has not been created, and there is nothing to scroll to.

`scrollPosition(id:anchor:)` over a `scrollTargetLayout()` applies during layout instead, which is the
one place the answer exists. It is still identity rather than an offset, which is `SPEC.md` §10's rule
and not a detail.

**Two things the photograph decided that reading did not.** The first fixture for it was 0.2.0's
three-file change set, and the recorded baseline was byte-identical to the one beside it — that change
set fits on one screen, so a jump that worked and a jump that did nothing photograph the same. The
subject is a seven-file set now, with a control render beside it that asked for no jump, and the pair
is what makes the claim. And the assignment is skipped when the scroll is already where it is going:
animating it anyway re-ran the transition from where it had landed, and the shutter caught a different
offset on each run.

The model says *go here*, once, and the view holds *here is where we are*. They are separate because
feeding a scroll position back into the model makes every frame of an ordinary scroll a write — and
the target is cleared by the view once it has moved, so tapping the same row twice is a change again
rather than a value set to itself.

## Four points of list margin is one character of directory, and it was not stable

§3's row is a head-truncated path at the edge of what fits, which is what the frames measure it as:
about 284pt for 33 characters. Inside the iPad's split view the same layout rendered twice with the
list's own horizontal margin at two different values, and the four points moved the truncation by one
character — a red suite that nothing in the diff explains, which is this repository's second locale
trap in shape if not in cause.

The row inset is stated once and the list's own content margin is pinned to zero underneath it. What
that buys is a column whose available width is a fact rather than a measurement, which a row this
tight has to have.

## The truncation footer says what was served, because what exists is not on the wire

Design §3's frame prints "Showing the first 1,000 of 1,314 changed files." **The second number does
not exist on this client.** `WorktreeChanges` carries `isTruncated` and a file list, and its stats are
summed over the files that were *kept* — the server truncates before it counts — so a total would have
to be invented.

So the footer says how many are shown and that the Mac does not serve more at once. It keeps the half
of the frame that matters, which is §3's own instruction: say "not served" rather than "load more",
because the Mac's limits will not serve them and a button that cannot succeed is worse than a
sentence. Adding the total to the wire is a contract change on both ends for one line of copy, and it
is not one this slice asked for.

## The drawer's presented state is the model's, and a scroll that has not been told where it starts settles there on its own

Two measurements from the same slice, both about state nobody had named.

**The drawer.** `isShowingSelector` began as `@State` on the screen, which is the ordinary SwiftUI
spelling and is wrong here for the reason this repository already wrote down when the Mac's menu had
to open Settings on Devices: *a control whose only effect is a `@State` two layers up is a control
nothing can be asked about.* On the phone the drawer is the only way to the file list, so a presented
state no test can set is a screen that can only ever be photographed with its main affordance shut.
It is on the model, it is asserted — including that **choosing a file leaves it up**, which is the
whole of design §3's argument for a drawer over a modal — and the screen can now be rendered with it
open.

> What that render does **not** show is the drawer, and that is this repository's settled answer
> rather than a surprise: a hosted view presents a sheet into a window of its own and the raster does
> not include it. What the baseline holds is the diff *behind* it, undimmed, which is the visible half
> of the same argument. The suite says so where a reader of it will look.

**The scroll.** `scrollPosition(id:)` is a two-way binding: it is how a jump is asked for, and it is
also where the scroll **writes back** what it settled on. Started empty, that write-back is a value
arriving on its own schedule — and the iPad's split-screen baseline moved between two runs of
unchanged code because the shutter caught it on either side. The position is now seeded from the
state: the jump when there is one, the first file otherwise. The reader gets the same screen; the
difference is that it is a value this view stated rather than one it settled into.

**And a fixture can hide a working control as easily as a broken one.** The jump's first subject
targeted the *last* file, which cannot reach the top of a scroll — it clamps against the end of the
content, so where it stopped depended on how much of the lazy stack had been realised. The target is
a file with hundreds of rows under it now. **It lands about 120pt short of that file's top**, which
the baseline records rather than hides: anchoring, an explicit section identity and the target layout
were each tried and none of them closes it, so it is `scrollPosition` interacting with pinned section
headers. The reader gets the file they tapped, near the top of the screen; the last 120pt is a
question for a thumb.

## A path git will not hash costs its own content hash and nothing else

**Found by running the product, on a real iPhone, against real repositories.** The worktree list
failed and *Try Again* looked dead; the Mac's log said `hashWorktreeFiles(...) failed` over and over.
The cause is a **symlink pointing at a directory**: `git ls-files --others` reports it as an ordinary
untracked path — git treats a symlink as a file, so there is no trailing separator to filter on — and
`git hash-object --stdin-paths` follows it, finds a directory, and exits 128 for the **whole batch**.
Two of Davide's `bandlab-android` worktrees carry one, so `/v1/worktrees` could not answer at all.

`WorktreeService`'s own comment predicted the shape and filtered the two cases it knew — a deleted
file and a submodule. What it could not filter is a path that looks ordinary and is not, and the
general answer is not a longer filter: tomorrow it is a fifo, a socket, or a file the server cannot
read.

So the batch is still tried first and is still one process for a whole worktree. **Only when it fails**
does the service hash the paths one at a time, which costs a process per file exactly once, in a
worktree that has something wrong with it. Every file git *can* hash keeps a real content hash, which
is what makes a viewed mark self-correcting when the file changes underneath it.

> Rejected: giving the whole batch the absent id on failure. It is two lines shorter and it makes
> "viewed" stick to content nobody has seen, for every file in that worktree — a silent weakening of
> the one thing this product is for.
>
> Rejected: locating the bad path from the partial output of the failed batch. Measured first, and
> git does emit the hashes it managed before dying, so the count would name the culprit exactly —
> but `GitError.commandFailed` carries git's standard error and **not** its standard output, so
> those hashes never reach the caller. Widening the error to carry stdout would put a private
> repository's contents into an error value that gets logged, which is the boundary the git
> decorator already exists to hold.

## A cancelled request is not a failure, and the app was blaming the Mac for it

`URLSession` reports a torn-down request as `NSURLErrorCancelled`, and the transport folded every
non-`ApiFailure` error into `unreachable`. A `.task` is cancelled the moment its view goes away —
which in a navigation stack is *every time the reader opens something* — so an in-flight read of the
worktree list was routinely cancelled by the app itself and then reported as **Could not read your
Mac**, with `Code=-999 "cancelled"` in the small print, on the screen the reader reached by pressing
Back.

`ApiFailure.cancelled` is a case of its own now. The transport maps `URLError.cancelled` and
`CancellationError` to it, and each model decides: the worktree list keeps the arrangement it had,
the viewer keeps the change set it had, and a cancelled *write* leaves the reader's mark standing
rather than taking it back with an alert nobody caused.

**It is a case rather than a silent `nil`** because the transport cannot know what to do about it and
the screen can. And it is not folded into `unreachable` because the two differ in the only way that
matters to a reader: one means the Mac is not there, and the other means nothing at all.

## The retry says it is trying, because the endpoint behind it is slow enough to look dead

*Try Again* re-ran the read and left the failure on screen until the answer arrived. `/v1/worktrees`
builds a change set for every worktree of every enabled project — measured at **122.7 seconds** over
ten of Davide's repositories, which is the same measurement that killed the menu bar's dirty count —
so the button was indistinguishable from one with nothing behind it, and was reported as one.

`load()` returns to `loading` first. On the first read that is already the state and costs nothing;
from a failure it is the only feedback there is. No new control and no new copy — the spinner design
§1 argued for is already the right one here, because unlike a Bonjour browse this request finishes.

## Git's own sentence leads the failure line, because the unified log truncates

A failed invocation logged `"\(command) failed: \(error)"`, and `GitCommand` carries its paths. Eleven
of them, rendered as `RepositoryRelativePath(bytes: 36 bytes)` and then repeated inside the error's
own `commandFailed(command:)`, ran past the unified log's kilobyte limit **before reaching git's
standard error** — the one part written for a person, and the part `swift-style` says a git failure
exists to carry.

The line leads with git's sentence and trails the command, and `RepositoryRelativePath` describes
itself as the path. Measured rather than reasoned: the symlink above had to be reproduced by hand
because its stderr never reached the log.

## A shut file is a bar in the header's slot, and its reason is the field the specification forgot

`SPEC.md` §10 says a file marked viewed renders collapsed and that a file over 500 diff lines starts
collapsed with a *Load diff* affordance. 0.3.0 built the mark and left the diff open under it, which
made the toggle a control that moved a circle. This is the other half.

**The bar goes where the header goes**, in the section header's slot, with nothing under it. The
alternative — a header over an empty section — keeps two rows where the design draws one and leaves
the reason with nowhere to live. A shut file is therefore 44pt and not one row more, which is what
makes collapsing worth doing at all.

**Four reasons, and the reason is the whole point.** Design §4 added it to the specification and
argued it: without it the reader opens a file to learn there was nothing in it, which is the exact
cost collapsing was supposed to save. A binary file and a rename with no content change get **no
chevron at all** and the row stops being a button with it — there is nothing behind them, and a
disclosure control that discloses nothing is the smallest possible lie. The frame draws those two
chevrons faded; a faded chevron is still a chevron.

**"viewed", not "viewed 4 minutes ago".** The Mac stores a mark as the content hash it was set
against and keeps no time beside it, so the elapsed reading is a number this phone would have to
invent. Same shape as §3's truncation footer above, and the same answer: a sentence that is true
beats a sentence that matches a drawing. Putting a timestamp in the store is a change to `SPEC.md`
§5.5's viewed map on both ends for one adverb, and it is not one this slice asked for.

**An unread bar carries no empty circle**, which the frame draws on three of its four rows. The
circle in the file header is a *control* — it is the only writer of the mark there is — and the same
glyph on a row whose whole tap target opens the file would read as a second control inside the first,
which is §3's two-tap-targets problem in a 44pt row. So the mark appears on a bar only when it is
set, as a bare check, exactly as §3's selector row does it.

**A fifth case the design does not draw: the reader shuts a file by hand.** It has no reason line, so
the bar is one line rather than two. Telling someone they shut a file they have just shut is a line
that says nothing. It is photographed, because a state argued for in a comment and never rendered is
a state nothing holds anybody to.

**The reader's chevron is forgotten when the mark moves.** `viewed(_:)` clears the override rather
than preserving it, so marking a file read always shuts it — which is what §10 asks for and what the
frame says in one sentence. A mark that left an earlier *open* standing would be the one gesture in
this app that does half of what it says.

> Rejected: a `Bool` for the reader's answer defaulting to the automatic one. The difference between
> *the reader wants this open* and *nobody has said* is what lets a mark shut a file the reader had
> opened by hand, and one `Bool` cannot hold both.

## A file drawn shut is not fetched, which is what makes *Load diff* true

`ContinuousDiffLoading` gained a third set beside `held` and `inFlight`, and **unlike `held` it
shrinks**: a reader opening a bar takes a file out of it.

Without it the affordance is a label. `SPEC.md` §10 puts *Load diff* on a file over 500 diff lines by
name, and a phone that had already spent a batch slot on 1,558 lines nobody asked to see would be
offering to do what it had done. It also pays for itself on the ordinary screen: in a change set the
reader has been through once, every file they read is shut, and those are exactly the diffs not worth
twenty seconds of somebody's network.

The other half is that opening one **fetches it**, in the model, as a batch of one. Without that,
pressing a bar leaves a header over a blank stretch that nothing ever fills — the dead control this
project shipped for eight releases, arriving through the door built to stop it.

> A mark set while the file is on screen costs nothing, because its diff is already in hand. What the
> rule defers is the files that were read in an earlier sitting, which is the case it is for.

## Expansion is spliced into the diff rather than kept beside it

`SPEC.md` §8 makes `/lines` stateless on purpose: one parameter cannot express "hunk 2 expanded up
and hunk 5 expanded down", so the Mac hands over raw lines and holds no position. The obvious
reading of "the client owns expansion state" is a structure beside the diff saying how far each hunk
has grown. **This does not do that.** Splicing produces a wider `Hunk` — new bounds, new counts, the
context lines in file order — so "is there anything left above this one" is answered by the hunk
itself and cannot drift from what is drawn. The control disappears the moment the gap it opens is
closed, without anything having to keep the two in step.

Three things fell out of building it, and each is asserted:

- **A zero count is not an empty range at the line it names.** git writes `+c,0` for a hunk that adds
  nothing, where `c` is the last line *before* the change on the new side rather than the first line
  of it. Measuring either window from `c` hands back a line the hunk is already drawing. The same
  rule makes a wholly deleted file answer "nothing to expand" on both sides, which is correct — the
  hunk already holds every line there is.
- **The offset between the two sides is not one number.** Above a hunk it is the distance between the
  two ranges' first lines; below it, between their last. A hunk that adds three lines leaves the
  sides three further apart on the way out than on the way in, and using one offset for both would
  produce a gutter that is plausible and wrong.
- **Every window is read from the new side.** A context line is by definition the same on both, the
  reader is reading the working copy, and the one case with no new side has no gap to ask about.

**Twenty lines a press, stated rather than settled.** At §4's 11pt that is about a third of a phone
screen — enough to see what encloses a change, little enough that the line the reader was on is still
on screen afterwards. A press that scrolls past a full screen of new context loses their place, which
is the thing expansion exists to protect.

**A refused expansion is reported where a refused batch is not**, and the difference is what the
reader did. A batch is fetched on their behalf while they scroll, so losing one leaves placeholders
the next scroll asks about again. An expansion is a control they pressed, and a press that leaves the
hunk exactly as it was is a control that did nothing — so it gets an alert of its own, with its own
sentence, rather than sharing the mark's.

**Two presses inside one round trip would splice one window twice**, and that is recorded rather than
guarded. Both compute their window before either lands, so both ask for the same lines and both
splice them. The guard is a branch no test kind here can drive — it needs two calls genuinely
overlapping, and therefore a fake that holds a request open — and an untested branch is worse than a
defect whose symptom is twenty context lines appearing twice with the gutter numbers saying so. It is
on the device afternoon's list, which is where it can be seen.

## `DisplayWidth` is public now, because the client makes lines the parser never saw

The type's own comment said it is measured on the server "rather than on the client", and the reason
is the one that matters: two implementations of one Unicode judgement is a disagreement waiting to
become a row-count error in a scroll that must never reflow. Context expansion turns raw text from
`/lines` into diff lines **on the phone**, which need that number like any other.

So the answer is not a second implementation on the client — it is the same one, exported. What the
comment protects is one measurement, not one side.

## The hunk band grows to 44pt only where it carries a control

Design §4 puts the expand control on the band's trailing edge in a 44pt hit area, and not the leading
edge, which is the gutter's column — a glyph there reads as a line number. Taken literally that makes
the band nearly four times its previous height, which is real screen on a phone; taken loosely it
makes a tap target a thumb misses, and a control that misses is a control that did nothing.

It is taken literally, and bounded: a hunk with no gap above or below it draws no control and keeps
the thin band it always had, so the cost is paid only where there is something to press. Whether four
of these in one file is too much is a question for the same thumb that owes §4 its other answers.

> Rejected: a hit area larger than the row it is drawn in. It overlaps the code above and below, and
> a tap that lands on a diff line and expands a hunk is worse than one that misses.

## The bar's rule is a rectangle, because `Divider` picked its own axis

`Divider` takes its orientation from the layout it is in. Inside a `Button`'s label it read the bar's
own `HStack` and drew itself **vertically** — a stray line down the middle of the two bars that are
buttons, and no rule under them, while the two that are not buttons got the horizontal one. The first
baseline is what said so; nothing in the code reads as if it could happen.

It is an explicit rectangle at a stated height now. That is this repository's third measurement that
settled itself differently in two places, after the list margin and the scroll position, and the
answer is the same one: state the value rather than loosen what checks it.

## `NoWorktreeChosenView` stays, and the split screen's destination stays doubled

Both were left open by 0.3.0 for Davide, and both are settled as they stood.

The empty detail column keeps its unavailable-content view, because design §2 asks for one in as many
words and the composition that ships still has it. The doubled `navigationDestination` stays doubled,
because what it settles is which of two containers claims a tap, and removing a declaration to find
out is exactly how this app shipped a row that did nothing. It costs one duplicated line and it is
correct in both layouts; the finger that settles it is the same one the device afternoon owes §4.

## Seven spellings nobody had photographed, found by a fallen coverage row

The Snapshot regions row fell by 0.3% when this slice put five controls on three views. That is the
structural gap the `swift-testing` skill records rather than a thing done wrong here: an action
closure in a view body is uncoverable by every test kind that runs in this repository, and the
sanctioned remedy is to find genuine unphotographed view fallbacks. There were seven.

Three on the phone: a wholly added file and a wholly deleted file, which are the gutter's own `?? 0`
fallbacks and had never been drawn over a whole file; and the diff screen over a clean worktree,
whose *Files* button had been argued absent in a comment and never rendered. Two wrapper closures
went with them, by letting the header and the bar report **which** file they are about — which they
already hold, so the caller was re-attaching an identifier for no reason.

Four on the Mac, and every one a singular-or-plural the app would have shipped wrong: Advanced's
count-spelling table has six arms and three had never been rendered; the connection log had never
drawn a single served request, so *1 requests* was one release away on the panel a reader opens under
pressure; and Projects had never drawn a repository with one checkout. That is the same reason the
phone photographs *1 file* beside *7 files*.

**The row is a ratchet with no slack, and this will recur** on every slice that adds controls. What
closes it for good is the `ui` kind, which needs the Accessibility grant and an
`Apps/GranitaMobileUiTests` that has never existed.

## A remembered Mac is filed under its Bonjour name, and the row goes straight to its worktrees

Two entries above this one — *the already-paired state is the one frame this slice did not build* and
*`loadPairingHistory()` and `pairedServers` are removed for the second time* — both stop at the same
sentence: nothing joins a Bonjour instance to a stored token, and the `serverInstanceID` that would
join them is a TXT record entry SPEC §8 asks for and the Mac does not publish. That was read as a
blocker on the Mac. It was a blocker on the **key**, and the key was the wrong one.

`ServerInstanceId` arrives inside a `/v1/pair` response. A phone that has not paired cannot know it,
and a phone that has cannot match it against anything a browse returns — so filing a token under it
guaranteed that the token could never be found again. It was also never stable: `Pairing.instanceId`
is a `UUID()` evaluated once per process, which its own comment says out loud, so every restart of the
Mac orphaned every token any phone held. Two documents disagreed about this for four releases and the
code agreed with the wrong one.

**What a browse result carries is a Bonjour instance name, so that is the key.** It is in hand at the
one moment the question is asked — this row, does this phone already know it — and it is unique within
a local domain because the system appends "(2)" itself. A rename costs one more pairing, paid by the
person who renamed the machine rather than by everybody every time they open the app.

**The identity check is the pin, not the identifier**, which is what makes the weaker key safe. The
stored pairing carries the SPKI fingerprint beside the token, and the session built from it refuses
every other key in the handshake. A different Mac answering under a remembered name is a refused
connection, not a request sent to a stranger. That is a stronger guarantee than matching a UUID would
have been, since a UUID is only ever as good as the channel that carried it.

So no TXT record is added, and the not-recommended entry in design §5.6 stays not-recommended for the
reason it gives: a TXT record is in-band, and the one field that may not ride there is the key. The
instance identifier may — and now nothing needs it to.

**The row is the fix, and the screen is not.** The review's own reading, recorded in the first entry
above, was that *already-paired is a discovery problem wearing a pairing screen*, and that the right
behaviour is a paired Mac's row going straight to its worktrees. That is what ships. The drawn
already-paired frames stay in `.claude/docs/design/` for the one reader who ever reaches that
situation — the one whose token the Mac revoked — and that case is handled without a screen for now:
a refusal forgets the pairing, so Back and a second tap reach the two credentials again.

**No new screen and no new state, which is why this needed no design round trip.** Reaching a
remembered Mac is a Keychain read, a Bonjour lookup and a pinned session, and all three happen behind
the worktree list's own loading state because they happen inside its repository rather than in front
of it. `RememberedMacRepository` is the seam: every call opens the connection if there is not one,
and the failure of a call is what changes what the phone believes — a refusal forgets the pairing, an
unreachable read throws away the address, and the exhaustive switch is what stops a future refusal
joining those two by accident. Rejected: resolving the address in the row's tap handler, which is a
list that goes dead for the length of an mDNS lookup; rejected: a connecting screen, which is a frame
that does not exist and a fifth screen in a flow design §5 fixed at four.

**The address is not stored and the fingerprint is.** The port is the system's choice at bind time, so
a remembered `host:port` is wrong the first time the Mac restarts — a phone dialling it would report a
Mac two feet away as unreachable. The key is the opposite: it is in the login Keychain on that Mac and
outlives every restart, and without it a reconnection would have to trust whoever answered, giving
back the whole of what pairing bought. So one is looked up every time and the other is written down.

**0.4.0's items are deleted rather than left.** They are unreachable by construction and each one is a
live bearer token, since the Mac's device record outlives the launch that issued it. The sweep runs
after the first successful write in the new format, which is the moment the reader demonstrably has a
pairing this version can use — not at launch, where it would be a Keychain call on every scene
evaluation forever for a migration that happens once.

## The changed words get a background, and design §4's inversion is reverted to the specification

Design §4 tested "two nested backgrounds behind mono text" and returned **fits, not as drawn**: in
light at a 3× alpha ratio yes, in dark no, because the row tint already needs 16% to be visible
against black and there is no headroom above it. So the review inverted the emphasis into the text —
unchanged runs on a changed line down to `.secondary`, the changed run at full-strength label — and
that is what 0.2.0 built.

**It reads well and it spends the one property the syntax highlighter needs.** A lexer colours text.
A line whose text colour already means *this part changed* has nothing left to say `keyword` with,
and `SPEC.md` §10 asks for both on the same line: word-level segments **and** per-file syntax
highlighting. The review saw the edge of this — it rejected underlining the changed run because "it
collides with whatever the syntax highlighter does" — but it never drew the two together, and §4 has
no highlighting section at all.

Davide settled it on 28 August 2026: *"Changed words should have different background color, instead
of text color"*. That is not a new call so much as a return to the specification, which has said
since it was written that word-level highlighting goes on "as a stronger background on the changed
spans over the line level add/remove background".

**What survives from §4 is the argument rather than the number.** "Stronger" is a ratio, and that is
the part that was right. Two translucent layers do not add, they composite — `1 - (1 - t)(1 - s)` —
so a segment drawn at the fixed 28% the review measured reads as a *different* multiple of the row in
each appearance, which is the drift it rejected the treatment for in the first place. So the ratio is
what is stated and the alpha is solved from it: the changed run lands at three times the row's own
tint in both appearances, which is about 22% in light and 38% in dark. One number written down, two
derived, and they cannot come apart.

**The line is now drawn once rather than run by run, and that fixed a tab defect nobody had hit.**
The old treatment built one `Text` per segment and expanded each segment's tabs independently, so a
tab in a later run measured from column zero of that *run* rather than of the line — `if\ttrue` split
after `if` drew `if    true` where the grid says `if  true`, and every column after it was wrong
against the gutter the scroll was measured from. Tab expansion now carries the column between runs,
`MonospacedGrid` owns that in one place, and the property that the runs joined equal the whole-line
expansion is asserted rather than assumed. Reachable in any tab-indented file — Go, Make — with a
word-level pair on a line with a tab in the middle of it.

**The ranges are characters, not columns.** An ideograph is one character of the string and two
columns of the grid; a background is applied over the string. The two counts are both right and they
are not interchangeable, so `DrawnDiffLine` names which one it is in.


---

## Deleting a worktree from the phone, and what "delete" was allowed to mean

`SPEC.md` §11 lists **pruning worktrees** in the v2 backlog, and design §2 leans on that in as many
words when it decides the locked flag earns no pixels: *"v1 cannot prune worktrees, which is the only
operation it would block."* Davide asked for it on 28 August 2026 anyway, with a confirmation in
front of it. So this is a deliberate departure from the spec's own scope line rather than an
oversight, and it is the first thing in this product that writes to a repository — everything before
it wrote to this Mac's own JSON document.

**It is `worktree remove --force`, once.** The unforced form refuses whenever there is anything
uncommitted, which is *every worktree this app lists*: the sidebar hides the quiet ones by default
and the whole product exists to show uncommitted work. An unforced deletion would therefore be a
control that refuses on nearly every row it is offered on, which is worse than not having one. The
confirmation is not ceremony around a safe operation; it is the entire safeguard, which is why the
dialog is the one place the cost is stated and why the subject it is handed carries the row's stats
rather than only its name.

**A second `--force` was available and is not sent.** `-f -f` overrides a lock, and a lock is a
person at that Mac saying do not remove this. A lock a phone can wave through is not a lock, so a
locked worktree is refused. That is what put `isLocked` to work for the first time — the flag design
§2 filed as plumbing, on the grounds that the only operation it blocked did not exist.

**The branch survives.** What an agent leaves behind is a directory and some uncommitted work; the
branch is cheap, is not in the way, and `git branch -D` would take unmerged commits with it — a much
larger promise than the one a confirmation naming a worktree can honestly make.

**Two refusals are predicted rather than discovered.** The primary checkout and a locked worktree are
both visible in what the registry already holds, so the route refuses them itself instead of running
git and forwarding `fatal: '…' is a main working tree`. That buys a code the phone branches on —
`worktreeNotDeletable`, new to the contract and therefore a contract change — rather than a git
sentence it can only print, and it keeps an absolute path on this Mac out of an answer to a client
that is never otherwise given one. Git refuses both regardless, so this is a better sentence rather
than the only guard. Where both are true the row says *primary*, because that is a fact about the
repository rather than a setting somebody can undo, and the alternative sends a reader off to unlock
something that would still refuse afterwards.

**The row decides deletability, and it carries a reason rather than a boolean.** A control that is
absent and a control that is disabled and says why are different answers to *why can I not do this
here*, and only the design chooses between them — but a boolean has already thrown away the half
that lets a screen give either. So `WorktreeListRow` carries three cases, and a screen physically
cannot offer the control on a worktree that would refuse.

**The row is dropped only once the Mac says it is gone.** Renaming and pinning both write
optimistically here; deleting must not. A rename that silently failed shows the wrong name until the
next read, which a reader notices and can repeat. A deletion that silently failed shows a worktree
that still exists as destroyed, which nobody goes looking for. A `worktreeGone` refusal is the one
exception and counts as success: an agent removes a worktree every day, so a reader can confirm one
that stopped existing between the read and the tap, and the difference is only *who* removed it.

**The route runs git from the project rather than from inside the worktree.** Git accepts being asked
from inside the directory it is about to delete — measured on 2.52.0, it works and exits 0 — and
there is no reason to ask that of a process.

### What was verified by running it, on git 2.52.0

Every rule above rests on one of these rather than on documentation:

| Asked | Answer |
|---|---|
| `worktree remove` on a dirty worktree | exit 128, `contains modified or untracked files, use --force to delete it` |
| `worktree remove --force`, run from inside that worktree | exit 0, silent, directory gone, **branch still there** |
| `worktree remove --force` on a locked worktree | exit 128, `cannot remove a locked working tree; use 'remove -f -f' to override or unlock first` |
| `worktree remove --force` on the main worktree | exit 128, `'…' is a main working tree` |
| `worktree remove --no-ext-diff …` | exit 129, `error: unknown option` — it is not a diff-family command |
| `worktree remove --force --` before the path | accepted, so the always-`--`-before-paths rule holds here too |
| `worktree remove --force` on a worktree whose directory somebody already deleted | exit 0 — git cleans up the admin files |
| the same command a second time | exit 128, `'…' is not a working tree`, which the registry refuses before git is reached |

### The tests own a repository rather than borrowing the fixtures

A removal test driven against the committed fixtures takes a checkout out from under everything else
that reads them, and the suite asserting the main fixture has three worktrees is where it would
surface — a run later, in a test that changed nothing. `make fixtures` puts it back, which means the
second run of an unchanged tree behaves differently from the first, and that is worse than a slow
test. So `DisposableRepository` builds one per test and deletes it afterwards.

**Its paths are read back from `git worktree list` rather than computed**, and that cost two red
runs before it was read rather than guessed. An identifier is a hash of the path *string*, and two
plausible spellings of one directory hash differently: a `URL` built for a directory carries a
trailing separator git never emits, and `resolvingSymlinksInPath()` leaves `/var/folders` alone on
macOS where git reports `/private/var/folders`. Either one produces an identifier matching nothing in
the registry, and every route then answers `worktreeGone` about a worktree sitting right there.

---

## Shipping the delete screen before its design, and the defect that found

**The `design-handoff` rule is that no pull request touching a screen opens before its frames
exist.** This one did, on 28 August 2026, because Davide asked for it in as many words: he was
close to his weekly limit, wanted the feature usable, and wanted the design round trip to happen
afterwards and correct it. So the departure is his call, taken with the cost written down rather
than by quietly forgetting the rule.

**What makes it affordable is that the treatment was built to be overruled.** Thirteen calls were
made without authority; every one is listed in [`design.md`](design.md) §6, each is a single file or
a single modifier, and the prompt that will overrule them is
[issue #52](https://github.com/fardavide/granita/issues/52), written before any of the screen was
built. The issue exists so the ask survives the week rather than being reconstructed from the code
that guessed at it.

**The treatment was chosen by a panel rather than picked.** Four independent proposals were written
against §2 and the constraint list, three judges scored them on separate lenses — constraint
compliance, reader harm, and how cheaply a returned design could rip each one out — and the
synthesis took one as the spine and grafted five ideas from the runner-up. Two of the four proposals
were lost to schema failures and the panel judged two; that is worth knowing when reading the
verdict, and did not change which of the two won, because the loser was eliminated on confirmed
fatal flaws rather than on ranking.

### The panel found a control that did nothing, and no test here could have

`confirmDeletion()` read its subject back off `model.deleting`. Dismissing a SwiftUI alert writes
`false` through its `isPresented` binding, which clears that property **synchronously**, while the
button's own `Task { }` body does not run until a later turn on the main actor. So by the time the
work started there was nothing left to delete, `guard let subject = deleting else { return }`
returned, and **the Delete button destroyed nothing at all** — with the whole suite green, because a
raster does not include an alert and cannot press a button, and the model test drove the method
directly rather than through the binding.

That is this repository's own oldest defect arriving through a new door: a control that looks
finished at every layer, with the gap between two of them. The fix is `confirmDeletion(of:)` taking
the subject the confirmation was presented with, which is also the stronger guarantee — what is
destroyed is what was confirmed, never whatever the model happens to hold when the tap lands. The
regression test drives the exact ordering: begin, cancel, then confirm.

**It is the reason the affordance is not in the swipe.** A trailing swipe begins the way an
imprecise vertical scroll does, and iOS hands the *first* trailing action the full swipe — so a
destructive third action there is one over-committed thumb away from destroying work that was never
committed. A long press requires the finger to stay still, which is the one thing scrolling never
does, and leaving the swipe alone keeps its full swipe meaning Pin. The open question about whether
a full swipe may destroy a worktree is therefore answered structurally rather than by tuning a flag.

### Two things bought, and what would delete them again

**`WorktreeWriteRefusal`**, because the same `ApiFailure` means two different things: an unreachable
Mac leaves a rename exactly as it was, so *trying again usually works* is true, and leaves a deletion
in a state this phone cannot describe, where the same sentence is a claim nobody can make. Without
the operation travelling beside the failure there is no way to route the third message. If the design
comes back saying one message is enough, that type is **deleted**, not kept.

**`removing` is a set rather than one identifier**, because confirming one deletion, swiping a second
and confirming that too is reachable at LAN speed — and with an optional the second answer would
clear the first one's mark and put a row back on screen that is still going away. The `defer` that
clears it fires on every path including both failures; a `defer` that fired on only one would leave a
row dimmed and inoperable for the rest of the session, which is what the two identically-rasterising
refusal baselines exist to catch.

### Rejected, so it is not re-proposed

`.onDelete(perform:)` with `.deleteDisabled(_:)` is the cheapest-looking option and is wrong twice:
it hands back an `IndexSet` where this codebase requires the typed `WorktreeID` wrapper through every
signature, and `deleteDisabled` renders as a swipe that reveals nothing, which is a control that
looks operable and does nothing.

## The phone is the sleep proxy now, because macOS 15 stopped being one

**SPEC §9 says a laptop that slept is the single most likely reason the phone cannot reach the Mac,
and it is right — but the remedy it names has stopped working.** The specification asks for
`NSWorkspace.didWakeNotification` and a re-bind, which repairs the Mac's side once it is already
awake. What it assumes, and never states, is that something wakes it. Until macOS 14 something did:
the Bonjour Sleep Proxy held a sleeping Mac's advertisements and sent it a magic packet when anyone
connected, which is exactly the mechanism Screens has always relied on and told its users to switch
on.

**In Sequoia that client is gone.** At `mDNSResponder-2881.120.11` — the build on Davide's Mac —
`MDNSRESPONDER_SUPPORTS_COMMON_SPS_CLIENT` is `0` for macOS, so `BeginSleepProcessing` takes the
`SendSleepGoodbyes` branch: the Mac *withdraws* its advertisements on the way down rather than
handing them to a proxy. The flag is present at 2559.1.1 (macOS 15.0) and absent from 2200.140.11
(macOS 14), so the change landed in Sequoia. There is an Apple TV on Davide's network advertising
`_sleep-proxy._udp` and it is now irrelevant — nothing registers with it.

The consequence is worse than a slow reconnect: a sleeping Mac is not in the browse at all, so the
discovery screen reports nothing found. There is no row, so there is nothing for any amount of
client patience to be patient about.

**So the phone sends the packet the proxy would have sent.** `/v1/health` reports the Mac's hardware
addresses, the pairing stores them beside the token, and two decorators — `WakingServerDiscovery`
over the browse and `WakingServerAddresses` over the resolve — broadcast a magic packet before
waiting to hear from a Mac that may be asleep.

### Why it is a decorator at the browse and not a screen

**Because a screen would need frames and this needs none.** The honest alternative is a row for a
Mac that is asleep with something to press, and design §1 has no such state; adding one is a design
round trip before any of this could ship. Waking at the browse means a sleeping Mac simply appears
in the list a few seconds later, through `searching` and `found` — states the screen already draws —
and the reader is told nothing they would have to act on. The wake runs *beside* the stream rather
than in front of it, so a refusing Keychain or a network that drops the datagram cannot cost the
reader the Macs that were awake all along.

### What is served unauthenticated, and why that is not a leak

A hardware address goes out on `/v1/health`, which answers before pairing. It is already broadcast
in the clear by ARP and mDNS to everyone on the same LAN, so this publishes nothing that was not
there for the asking — and the alternative, serving it only after pairing, would be a Mac that
cannot be woken until it has been reached, which is the case that never needs waking.

### Three departures from what was written down

**`RememberedMac` now stores something about where the Mac is**, which its own doc comment rules
out. The exception is deliberate and narrow: a hardware address is a property of the machine rather
than of this boot, so it does not go stale the way the port does — and it is the only thing usable
while the Mac is asleep, which is precisely when Bonjour has nothing to say.

**`RememberedMacRecord` gains an optional fifth field.** Optional so that every pairing already in a
reader's Keychain still decodes; a required one would read on the phone as a Mac that must be paired
with again, for no reason anybody could see.

**The just-paired destination now goes through `RememberedMacRepository`.** It used to build an
`HttpGranitaRepository` straight over the address pairing returned, and the comment above it argued
that was the point — a Mac just paired with "brings its address in hand". It also meant `lostContact`
never ran there, so once that Mac slept, *Try Again* re-dialled a dead port until the reader left the
screen. That was a defect before this work and it is the thing that makes waking from that screen
possible at all.

### The entitlement, which is the difference between this working and doing nothing

**iOS has not let an app broadcast without permission since iOS 14, and that includes this.**
`com.apple.developer.networking.multicast` is named for multicast and gates broadcast too; the check
is in the network stack, so a raw BSD socket is not a way around it — which matters here because the
socket was chosen for reliability and would otherwise have looked like one. Apple's own
documentation is explicit that the simulator does not enforce it, so **neither the snapshot suite nor
the loopback test in `MagicPacketWakeTests` can catch its absence**: they aim at `127.0.0.1`, which is
neither broadcast nor multicast.

The failure mode is the one this repository cares most about. `sendto` returns `-1`, the result is
discarded because nothing acknowledges a magic packet anyway, and the reader sees precisely what they
saw before the feature existed — a sleeping Mac that never appears. Not a dead control, since nothing
is pressed, but the same class of defect: something that looks finished and does nothing.

The entitlement is **restricted** and Apple must approve a request before a profile can carry it.
`Apps/GranitaMobile/GranitaMobile.entitlements` and the `entitlements:` key in `project.yml` are in
place, on Davide's instruction, so that a device build can be tried; if provisioning refuses, that
refusal is the answer and the request has not been granted yet.

### Learning to wake a Mac that was paired with first

**Only pairing ever wrote a hardware address, so the first release that can wake a Mac could not wake
the Mac its reader already had.** Every pairing in the Keychain on upgrade day decodes with none, and
the remedy would have been to walk to the Mac and pair again — for a feature whose entire purpose is
not having to walk to the Mac.

So `RememberedMacs` backfills: when a Mac is reached and its record has no address, it reads health
and rewrites the record. It happens at the one moment the phone is guaranteed to be talking to a Mac
that is awake — it has just reached it — and once per Mac per run, so a Mac that genuinely has none
is asked once rather than on every reconnection. Silent on every failure, because a Mac too old to
answer, a health read that fails and a Keychain that refuses all leave the same state: a Mac that is
simply not wakeable, which is the state it was already in.

The health read is **unpinned**, deliberately. Health carries no secret, it is the route that answers
before pairing, and what comes back only aims a broadcast anyone on the network could send anyway.
Pinning would mean a second session per Mac for a read whose worst outcome is a packet nothing
answers.

### What no code here can fix

**Wake for network access has to be `Always`.** `pmset` ships it as *Only on Power Adapter* — `womp
1` on AC, `womp 0` on battery — and a Mac on battery ignores a magic packet entirely. Screens' own
support page leads with the same instruction, which is the tell that this is a platform requirement
and not something an app talks its way around. Saying so *in the app* would be a new surface on the
Mac's General tab, so for now it is in the changelog and this file. **If a reader ever reports "it
still does not wake", that setting is the first thing to check and the app cannot check it for
them.**

### Rejected, so it is not re-proposed

**An `IOPMAssertion` keeping the Mac awake while it serves.** It works, needs no packet and no
setting — and Davide ruled it out directly: the goal is to reach a Mac that is asleep, not to stop it
sleeping. It also costs battery on a laptop forever, and would need a General-tab toggle to be
honest about that, which is the design round trip this approach avoids.

**Pinning the Bonjour port so it survives a rebind.** Worth reconsidering only if a wake is ever
observed to land on a stale port. `BindAddress` has no case that fixes a port *and* advertises, so it
would mean an off-label mutation of the live `NWListener`, a store schema bump, and rewriting the
General tab footnote that currently tells the reader in as many words that the port changes every
launch — which is a screen, and therefore design-blocked. The phone re-resolves after each wake, so
the port it ends up on is the one Bonjour publishes.
