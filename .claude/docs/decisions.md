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
