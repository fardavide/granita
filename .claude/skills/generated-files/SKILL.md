---
name: generated-files
description: The three artefacts that are generated AND committed — the Xcode project, the golden diff fixtures, the app icons — how to regenerate each, which are gated by CI, and the path-independence trap that cost two red runs.
when_to_use: >
  Consult before editing anything under Granita.xcodeproj, Core/Diff/DomainTests/Fixtures or an
  Assets.xcassets icon set; when adding a target, a scheme or a build setting; when the "Generated
  files" CI job goes red; and when changing Scripts/make-fixture-repo.sh or the icon artwork.
---

# Generated files

Three things here are produced by a script and committed anyway. Each is committed for a reason that
only surfaces at release time, and each has its own rule about staleness.

| Artefact | Source | Regenerate | Gated by CI |
|---|---|---|---|
| `Granita.xcodeproj` | `project.yml` | `make project` | yes |
| `Core/Diff/DomainTests/Fixtures/*` | `Scripts/make-fixture-repo.sh` | `make fixtures` | yes |
| `Apps/*/Assets.xcassets/AppIcon.appiconset/*` | `Art/icon/*.svg` | `make icons` | **no** |

`make verify-generated` runs the gated two and fails if anything moved. **Never hand-edit any of
them** — edit the source and regenerate.

## The Xcode project

`project.pbxproj` is never hand-edited: an agent editing one corrupts projects, which is the whole
reason XcodeGen is here. It is committed rather than ignored because Xcode Cloud requires a project
that is continuously present in the repository and reads its product list from **shared schemes**;
generating it at build time is explicitly unsupported.

XcodeGen emits a shared scheme only when `project.yml` declares a `schemes:` block. Without one it
emits none, silently, and Xcode Cloud's product list comes up empty with no explanation. The probe
that tells you the truth is the one Xcode itself uses:

```bash
xcodebuild -project Granita.xcodeproj -describeAllArchivableProducts -json
```

An empty array means Xcode Cloud will show you nothing.

## The golden diff fixtures

Generated from the real `git` binary, committed so the parser suite runs on a machine with no git,
and covering every case the spec's §6 lists. See the `swift-testing` skill for how to assert against
them.

The generator does more than produce output: it **asserts the behaviours the git layer is built on**
and fails loudly if one stops holding — the two `-z` rename layouts whose path orders are opposite,
`diff --no-index` exiting 1 on success, unborn HEAD, a conflicted path emitting a normal unified diff
rather than `diff --cc`, and a binary path yielding both the "differ" summary and a `GIT binary
patch`. That is why the CI job reports `git --version`: when it goes red on a fixture nobody touched,
a git upgrade is the first suspect.

### The path-independence trap

Fixtures must be identical whoever builds them and wherever. Two separate leaks cost two red CI runs:

- **An absolute path in a tracked file.** `.gitmodules` recorded an absolute submodule url, which
  changed the superproject's tree, its commit, and therefore every HEAD recorded in the worktree
  listing. A relative url fixes it.
- **Symlink resolution.** git reports worktree paths with symlinks resolved, and on macOS `/var` is a
  symlink to `/private/var`, so an output directory under `/var` escaped the path rewrite. The script
  resolves its own output directory before using it as the rewrite token.

`make verify-generated` therefore regenerates a **second time from a differently-named directory**
and diffs the result. Two runs in the same directory cannot catch this class of bug, which is exactly
why it reached CI twice.

If you add a fixture that embeds an absolute path, either rewrite the root to a fixed token — as
`worktree-list.z` does, and it is the only file edited on the way out — or move it to `.fixtures/`,
which is gitignored and is where tests that need a real repository look anyway.

## The app icons

Committed, but deliberately **not** gated: rasterising an SVG is not reproducible across machines or
OS releases, so a CI check would compare a runner's antialiasing against a laptop's and fail on
artwork nobody touched. `make icons` is manual, and it is on you to run it when `Art/icon/*.svg`
changes.

The two platforms need opposite files, and each mismatch is an App Store Connect reject rather than a
build failure:

- **iOS** takes a full square with **no alpha sample** — an alpha channel on the marketing icon is
  ITMS-90717 — rendered with the squircle clip **stripped**, because the system applies its own mask
  and would otherwise mask a baked-in one.
- **macOS** takes the **shaped** icon **with** alpha, at every slot in the ladder. Nothing masks a
  Mac icon for you, and with the mac slots empty the asset compiler emits no macOS icon at all
  (ITMS-90236).

Quick Look (`qlmanage -t`) is the obvious rasteriser and the wrong one: it composites onto white, so
a shaped icon comes back with opaque white corners. `Scripts/rasterise-svg.swift` draws through
CoreGraphics instead and the generator asserts the resulting PNG colour type on both paths.

The three SVGs are the three appearances iOS 26 and macOS 26 render — any, dark, tinted. Replacing
the artwork means replacing files in `Art/icon/` and running `make icons`; if the new artwork drops
the squircle clip, the generator fails rather than silently producing a double-masked icon.

## Inspecting a build product without destroying it

`plutil -extract <key> <format> <file>` **rewrites the file in place**. Without an explicit `-o -`
it does not print to stdout — it replaces the plist with the extracted value. That mistake truncated
an archived `Info.plist` from 1729 bytes to a 5-byte array during the Xcode Cloud prep, after which
every further check saw a plist with no keys and reported a missing `UIDeviceFamily` that had been
there all along.

- **Read a plist with `plutil -p <file>`.** It is read-only.
- Use `plutil -extract` only with `-o -`.
- More generally: a check that mutates what it measures produces a finding about itself. When an
  inspection reports something surprising about a build product, re-create the product before
  believing it.
