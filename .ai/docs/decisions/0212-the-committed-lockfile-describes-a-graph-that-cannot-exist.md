# The committed lockfile describes a graph that cannot exist, and a `ci_post_clone.sh` did not fix it

The 0.14.0 archive failed with nothing in this repository having changed:

    Could not resolve package dependencies: an out-of-date resolved file was detected …
    Running resolver because the following dependencies were added: 'swift-issue-reporting'

**Xcode Cloud builds with automatic dependency resolution disabled, which means it does not
resolve** — it validates the committed `Package.resolved` against the manifests and refuses the
build when they disagree. So any change to the dependency *graph* that nobody here made breaks the
archive, and the archive is the release.

What changed was a rename upstream. `swift-snapshot-testing` is declared `from: 1.19.4` and its own
`swift-custom-dump` dependency `from: 1.3.3`; pointfreeco renamed `xctest-dynamic-overlay` to
`swift-issue-reporting`, and a rename is a **new package identity**, so a newly published transitive
version added one. The committed file named the old identity and could not have named the new one:
it was written before the rename existed.

### Every check was green while the archive was not

The gate that exists for this cannot see it. GitHub's runners resolve automatically, so all seven
required checks passed on [#93](https://github.com/fardavide/granita/pull/93) — including two that
build both apps — against a resolved file Xcode Cloud would reject twenty minutes later. **A green
pull request is not evidence the release will build**, and this is the one failure mode where that
is true.

### The committed file describes a graph that cannot exist

`swift-custom-dump` **1.7.3** declares `swift-issue-reporting`, verified against the tag on GitHub
rather than against a checkout. The committed `Package.resolved` pins custom-dump at exactly 1.7.3
**and** pins `xctest-dynamic-overlay` at 1.13.1. No resolution produces that pairing, so the file is
not merely stale — it is describing something that is not a possible graph, and Xcode Cloud is right
to refuse it.

**The resolver that wrote it is the one that is wrong, and it is the one this repository pins.** A
scratch package depending on nothing but `swift-snapshot-testing` at Granita's own range, resolved by
plain SwiftPM with no workspace, no lockfile and no project state, produces the same pairing — so it
is not Xcode, not a cache and not the workspace. Cleared in order and to no effect: the package's
`.build`, the project's `SourcePackages`, SwiftPM's global cached clone of the pre-rename repository,
and its global manifest cache.

`swift-issue-reporting` is `xctest-dynamic-overlay` **renamed**, carrying its whole history, so the
old URL redirects and both names reach one repository with `1.x` and `2.x` tags on it. Asked for
`from: "2.1.0"`, Swift 6.3.3 (Xcode 26.6) pins **1.13.1 under the old name** — a version that cannot
satisfy the constraint it was resolving. That is a resolver fault, not a graph.

**Which makes the real cause a toolchain mismatch.** This machine is Xcode 26.6, and
`.github/actions/select-xcode` pins CI to 26.6 deliberately, "to keep environment-sensitive output
reproducible". Xcode Cloud chooses its own version in the workflow settings, and a resolver that gets
this right is what reports `swift-issue-reporting` as *added*. Cloud is not disagreeing with the
repository; it is disagreeing with a bug the repository's pinned toolchain committed to a file.

> **Superseded by the move to Xcode 27** (see the last entry in this file). The 27 resolver writes
> the correct graph, and Xcode Cloud moves to 27 along with it.

So the targeted fix is **to pin Xcode Cloud to 26.6 as well**, which is the pin that already exists
everywhere else and is the version the baselines were recorded against. Upgrading the repository to
Cloud's newer Xcode instead is the other direction, and it is a deliberate bump with re-recorded
baselines rather than a fix for this.

### Every check was green while the archive was not, twice

The gate that exists for this cannot see it. GitHub's runners resolve automatically, so all seven
required checks passed on [#93](https://github.com/fardavide/granita/pull/93) and again on
[#94](https://github.com/fardavide/granita/pull/94) — including the two that build both apps —
against a resolved file Xcode Cloud rejected minutes later. **A green pull request is not evidence
the release will build.** That is the durable lesson here whatever fixes the resolution.

### A `ci_post_clone.sh` was tried and removed

Apple runs `ci_scripts/ci_post_clone.sh` after the clone, which looked like the hook early enough to
resolve before the validation — `ci_pre_xcodebuild.sh` runs after resolution has already failed. It
called `xcodebuild -resolvePackageDependencies`, handing the job to the machine doing the building.
It merged as `e059fdd`, and the next archive reported:

    Running ci_post_clone.sh script failed (exited with code 74)

**So it ran, and `xcodebuild -resolvePackageDependencies` refused.** The script is `set -eu`, so 74 is
xcodebuild's own status. That is the answer to the question the hook was built on: with automatic
resolution disabled, Xcode Cloud does not merely decline to resolve *on its own* — it declines to
resolve **at all**, including when asked explicitly. There is no hook early enough, because earliness
was never what was in the way.

It therefore did not just fail to help; it added a second failure, ahead of the first and with a
number instead of a sentence. Removed on Davide's instruction the same night: *"Please get rid of the
ci script if not necessary."* **The lesson worth keeping is that the setting is not a preference about
when resolution happens — it is a refusal to resolve**, so every fix has to be a file that is already
correct when the clone lands, or the setting itself.

**Rejected: hand-writing the resolved file.** It is generated, and a file edited by hand stops
describing anything — the same rule that forbids hand-editing the pbxproj.

**Rejected: pinning the snapshot library to an exact version.** It does not reach the problem.
Whatever `swift-snapshot-testing` is pinned to, it declares its own dependency with `from:`, so the
transitive graph keeps floating and the next rename lands the same way.

**Rejected: turning automatic resolution back on in the Xcode Cloud workflow.** It unblocks the
release in a click and it hides the fault rather than fixing it — Cloud would then resolve a graph
the committed lockfile does not describe, on a toolchain the repository does not pin, and nothing
anywhere would record either. Kept as the emergency lever, not as the answer.

