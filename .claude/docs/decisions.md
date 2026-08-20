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
