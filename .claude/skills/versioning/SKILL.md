---
name: versioning
description: Granita's version-bump and changelog convention — patch for fixes, minor when a feature slice lands, major only when Davide calls it, the README changelog in lockstep, and the build number left alone because Xcode Cloud writes it.
when_to_use: >
  Consult before bumping the version or opening a pull request that adds user-visible behaviour —
  editing MARKETING_VERSION in project.yml, or when Davide says "bump the version" or "cut a
  release". Also whenever a change lands that warrants a changelog entry.
---

# Versioning

The version lives in **one place**: `MARKETING_VERSION` under `settingGroups.shared` in
`project.yml`. Both app targets inherit it, so a bump is a one-line edit followed by
`make project` to regenerate the committed Xcode project.

| Bump | When | Who initiates |
|---|---|---|
| Patch `0.0.X` | Bug fixes, corrections, internal work with a user-visible effect | Agent, by default |
| Minor `0.X.0` | A feature slice lands — something a reader can now do that they could not | Agent, when the slice completes |
| Major `X.0.0` | A big milestone | **Davide only — never propose, never apply** |

**"A feature slice" is narrower than "a feature".** The test is whether someone using Granita can do
something they could not before, not how much code arrived. A milestone from `status.md` is a slice;
new modules are not evidence of one. **When in doubt, patch.** A patch that should have been a minor
costs nothing; a minor that should have been a patch spends a number that is meant to mean something.

The scaffold is `0.0.1`. The first minor lands with the first milestone a reader could use.

## Do not touch `CURRENT_PROJECT_VERSION`

It is a placeholder. The shipped build number is Xcode Cloud's own monotonically increasing run
number, written into the project by `ci_scripts/ci_pre_xcodebuild.sh` at build time. Bumping it by
hand achieves nothing and invites a duplicate — App Store Connect refuses a build number that repeats
within a release train, meaning across every build sharing one `MARKETING_VERSION`.

## The changelog moves with the version

Every bump carries a matching entry in the `## Changelog` section of `README.md`, in the same pull
request. Newest first, heading exactly `### <version> — <YYYY-MM-DD>` with an em dash.

Entries are **user-facing**: what changed for someone reading diffs on their phone, not what changed
in the code. A bold lead-in sentence per bullet, then the explanation. If a change has no
user-visible effect it gets no entry — and if it has none, ask whether it warranted a bump.

**A bump with a stale changelog is a defect**, not a tidy-up for later.

## Merging to `main` publishes

Every squash merge to `main` triggers an Xcode Cloud archive: the phone app lands on TestFlight for
internal testers, and the Mac app is notarised. So a merge is a release, and the changelog entry and
`MARKETING_VERSION` must be right **before** the pull request goes green — a build cannot be
un-published, and the only fix is another build.

`[ci skip]` in a commit title suppresses the archive, which is the escape hatch for a docs-only
merge.

## Landing

`main` is PR-gated by the `protect-main` ruleset: branch, open a pull request, wait for all four
checks, squash merge. The pull request that carries the change carries its bump and its changelog
entry. Tag `main` after the merge — the ruleset targets branches, not tags:

```bash
git tag v<version> && git push origin v<version>
```
