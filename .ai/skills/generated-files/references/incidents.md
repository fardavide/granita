# What went wrong, and what each rule is made of

Evidence behind the rules in the `generated-files` skill. Every entry here is something that reached
CI, a release check, or a red pull request once.

## Contents

- The path-independence trap — two red CI runs
- Why the fixture generator asserts rather than just emits
- Why the Xcode project is committed, and the empty-product-list trap
- How the scheme rewrite turned a docs-only commit red
- The two resolvers that disagree about `Package.resolved` — 30 pins vs 26
- Why the icons are not gated, and the two App Store rejects they avoid
- The inspection that destroyed what it measured (`plutil -extract`)

## The path-independence trap — two red CI runs

Fixtures must be identical whoever builds them and wherever. Two separate leaks cost two red runs:

- **An absolute path in a tracked file.** `.gitmodules` recorded an absolute submodule url, which
  changed the superproject's tree, its commit, and therefore every HEAD recorded in the worktree
  listing. A relative url fixes it.
- **Symlink resolution.** git reports worktree paths with symlinks resolved, and on macOS `/var` is
  a symlink to `/private/var`, so an output directory under `/var` escaped the path rewrite. The
  script resolves its own output directory before using it as the rewrite token.

`make verify-generated` therefore regenerates a **second time from a differently-named directory**
and diffs the result. Two runs in the same directory cannot catch this class of bug, which is
exactly why it reached CI twice.

## Why the fixture generator asserts rather than just emits

It **asserts the behaviours the git layer is built on** and fails loudly if one stops holding:

- the two `-z` rename layouts whose path orders are opposite
- `diff --no-index` exiting 1 on success
- unborn HEAD
- a conflicted path emitting a normal unified diff rather than `diff --cc`
- a binary path yielding both the "differ" summary and a `GIT binary patch`

That is why the CI job reports `git --version`: when it goes red on a fixture nobody touched, a git
upgrade is the first suspect.

## Why the Xcode project is committed, and the empty-product-list trap

Xcode Cloud requires a project that is continuously present in the repository and reads its product
list from **shared schemes**; generating it at build time is explicitly unsupported.

XcodeGen emits a shared scheme only when `project.yml` declares a `schemes:` block. Without one it
emits none, **silently**, and Xcode Cloud's product list comes up empty with no explanation.

The probe that tells you the truth is the one Xcode itself uses:

```bash
xcodebuild -project Granita.xcodeproj -describeAllArchivableProducts -json
```

An empty array means Xcode Cloud will show you nothing.

## How the scheme rewrite turned a docs-only commit red

Xcode normalises `Granita.xcodeproj/xcshareddata/xcschemes/*.xcscheme` the moment the project is
opened — it rewrites the scheme `version` and sets `BuildableName` to the resolved product name
(`Granita.app`) where XcodeGen writes the target name (`GranitaMobile.app`).

Both work; Xcode Cloud resolves the target by `BlueprintIdentifier`, not by that string. But the
committed schemes are **XcodeGen's output**, so Xcode's rewrite is drift.

That is exactly how it landed in a documentation-only commit and turned a pull request red — a
`git add -A` straight after an Xcode session.

## The two resolvers that disagree about `Package.resolved`

There is one `Package.resolved`, at `Packages/Granita/Package.resolved`, and **two things write
it**:

| What ran | Result |
|---|---|
| `xcodebuild` / opening the project | 30 pins — the project's remote packages **and** the package's own |
| `swift build`, `swift test`, `make test` | 26 pins — the package's own only |

Xcode treats the local package as the graph root and writes the union there.

It does **not** write `Granita.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`;
that file is never created, which is why no CI cache may be keyed on it — `hashFiles` returns empty
for a missing file, so every run would collide on one key while appearing to cache.

**The union is what must be committed.** Xcode Cloud disables automatic dependency resolution and
refuses a stale resolved file, so the stripped version fails the archive — after the merge, as an
email, with no red check to have caught it. A CI step asserts the committed file still covers the
Xcode graph, which turns that silent post-merge failure into a red check on the pull request.

**A correction worth keeping:** an earlier revision of the skill claimed `xcodegen generate` wipes
the workspace resolved file. It does not — the file simply never exists. The test that produced that
claim checked for a file that had never been created, so it failed for the wrong reason and read as
a wipe.

## Why the icons are not gated, and the two rejects they avoid

Rasterising an SVG is not reproducible across machines or OS releases, so a CI check would compare a
runner's antialiasing against a laptop's and fail on artwork nobody touched.

The two platforms need opposite files, and each mismatch is an App Store Connect reject rather than
a build failure:

- **iOS** takes a full square with **no alpha sample** — an alpha channel on the marketing icon is
  **ITMS-90717** — rendered with the squircle clip **stripped**, because the system applies its own
  mask and would otherwise mask a baked-in one.
- **macOS** takes the **shaped** icon **with** alpha, at every slot in the ladder. Nothing masks a
  Mac icon for you, and with the mac slots empty the asset compiler emits no macOS icon at all
  (**ITMS-90236**).

Quick Look (`qlmanage -t`) is the obvious rasteriser and the wrong one: it composites onto white, so
a shaped icon comes back with opaque white corners. `Scripts/rasterise-svg.swift` draws through
CoreGraphics instead and the generator asserts the resulting PNG colour type on both paths.

The three SVGs are the three appearances iOS 26 and macOS 26 render — any, dark, tinted. If new
artwork drops the squircle clip, the generator fails rather than silently producing a double-masked
icon.

## The inspection that destroyed what it measured

`plutil -extract <key> <format> <file>` **rewrites the file in place**. Without an explicit `-o -`
it does not print to stdout — it replaces the plist with the extracted value.

That mistake truncated an archived `Info.plist` **from 1729 bytes to a 5-byte array** during the
Xcode Cloud prep, after which every further check saw a plist with no keys and reported a missing
`UIDeviceFamily` that had been there all along.

The general lesson: a check that mutates what it measures produces a finding about itself. When an
inspection reports something surprising about a build product, re-create the product before
believing it.
