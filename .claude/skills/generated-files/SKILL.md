---
name: generated-files
description: The three artefacts that are generated AND committed — the Xcode project, the golden diff fixtures, the app icons — how to regenerate each, which are gated by CI, the two commands to run before committing after Xcode or swift test, and the path-independence trap that cost two red runs.
when_to_use: >
  Consult before editing anything under Granita.xcodeproj, Core/Diff/DomainTests/Fixtures or an
  Assets.xcassets icon set; when adding a target, a scheme or a build setting; when the "Generated
  files" CI job goes red; after opening the project in Xcode or running swift test; and when
  changing Scripts/make-fixture-repo.sh or the icon artwork.
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

Each rule below was paid for once. What went wrong, the measurements and the App Store reject codes
are in [incidents.md](references/incidents.md); read it before working around one of these.

## Two commands to run before committing

- **After opening the project in Xcode, run `make project`.** Xcode rewrites the shared schemes on
  open, and that drift turns the "Generated files" job red. Never `git add -A` straight after an
  Xcode session without checking what it touched.
- **After running `swift test` or `swift build`, run `make resolve`.** Those resolvers write a
  *stripped* `Package.resolved`; the union Xcode writes is what must be committed, or the Xcode
  Cloud archive fails after the merge with no red check to have caught it.

## The Xcode project

`project.pbxproj` is never hand-edited: an agent editing one corrupts projects, which is the whole
reason XcodeGen is here.

**`project.yml` must declare a `schemes:` block.** Without one XcodeGen emits no shared scheme,
silently, and Xcode Cloud's product list comes up empty. Verify with
`xcodebuild -project Granita.xcodeproj -describeAllArchivableProducts -json` — an empty array means
Xcode Cloud will show you nothing.

## The golden diff fixtures

Generated from the real `git` binary, committed so the parser suite runs on a machine with no git,
and covering every case the spec's §6 lists. See the `swift-testing` skill for how to assert against
them.

The generator does more than produce output: it **asserts the behaviours the git layer is built
on** and fails loudly if one stops holding. That is why the CI job reports `git --version` — when it
goes red on a fixture nobody touched, a git upgrade is the first suspect.

**Fixtures must be identical whoever builds them and wherever.** If you add one that embeds an
absolute path, either rewrite the root to a fixed token — as `worktree-list.z` does, and it is the
only file edited on the way out — or move it to `.fixtures/`, which is gitignored and is where tests
that need a real repository look anyway.

`make verify-generated` regenerates a second time from a differently-named directory and diffs the
result, because two runs in the same directory cannot catch this class of bug.

## The app icons

Committed, but deliberately **not** gated — rasterising an SVG is not reproducible across machines.
`make icons` is manual, and it is on you to run it when `Art/icon/*.svg` changes.

**The two platforms need opposite files, and each mismatch is an App Store Connect reject:**

- **iOS** takes a full square with **no alpha**, squircle clip **stripped** — the system applies its
  own mask.
- **macOS** takes the **shaped** icon **with** alpha, at every slot in the ladder.

**Do not rasterise with Quick Look (`qlmanage -t`)** — it composites onto white, so a shaped icon
comes back with opaque white corners. `Scripts/rasterise-svg.swift` draws through CoreGraphics and
the generator asserts the resulting PNG colour type on both paths.

The three SVGs are the three appearances iOS 26 and macOS 26 render — any, dark, tinted.

## Inspecting a build product without destroying it

- **Read a plist with `plutil -p <file>`.** It is read-only.
- **Use `plutil -extract` only with `-o -`.** Without it, the command rewrites the file in place
  rather than printing — it replaces the plist with the extracted value.
- More generally: a check that mutates what it measures produces a finding about itself. When an
  inspection reports something surprising about a build product, re-create the product before
  believing it.
