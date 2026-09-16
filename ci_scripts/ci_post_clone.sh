#!/bin/sh
# Xcode Cloud custom build script — runs immediately after the repository is cloned, and before
# Xcode Cloud resolves package dependencies.
#
# Xcode Cloud finds this directory because it sits next to Granita.xcodeproj. The name and location
# are fixed by Apple: `ci_scripts/ci_post_clone.sh`, top level, executable bit committed. The order
# is what makes this the right hook rather than `ci_pre_xcodebuild.sh` — by the time that one runs,
# resolution has already happened and already failed.
#
# **It exists because Xcode Cloud resolves with automatic resolution disabled**, which means it does
# not resolve at all: it validates the committed `Package.resolved` against the manifests and
# refuses the build when they disagree. Anything that changes the dependency *graph* without anybody
# touching this repository therefore breaks the archive, and the archive is the release.
#
# That is not hypothetical. On 15 September 2026 the 0.14.0 archive failed with:
#
#     Could not resolve package dependencies: an out-of-date resolved file was detected …
#     Running resolver because the following dependencies were added: 'swift-issue-reporting'
#
# Nothing in the repository had changed. `swift-snapshot-testing` is declared `from: 1.19.4`, its own
# `swift-custom-dump` dependency is declared `from: 1.3.3`, and pointfreeco had renamed
# `xctest-dynamic-overlay` to `swift-issue-reporting` — a rename is a new package identity, so a
# newly published version of a transitive dependency added one. The committed file still named the
# old identity and could not have named the new one, because it was written before the rename.
#
# **Resolving here hands that job back to the machine that is building.** It is also the only place
# it can be done: the file is generated, a developer's toolchain may resolve a different graph than a
# clean runner does, and hand-writing one is how a lockfile stops describing anything.
#
# The cost is that the committed `Package.resolved` drifts from what ships, and that is a deliberate
# trade rather than an oversight — see `.ai/docs/decisions.md`. GitHub's own checks resolve
# automatically and so never see this, which is why every check on the pull request was green while
# the archive was not.
set -eu

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
    echo "note: CI_BUILD_NUMBER unset — not an Xcode Cloud build, leaving dependencies alone"
    exit 0
fi

REPO="${CI_PRIMARY_REPOSITORY_PATH:?}"
PROJECT="$REPO/Granita.xcodeproj"

if [ ! -d "$PROJECT" ]; then
    echo "error: no project at $PROJECT" >&2
    exit 1
fi

# `-resolvePackageDependencies` takes the project rather than a scheme: the graph is the project's,
# every scheme shares it, and naming one would make this file a second place that has to be edited
# when the scheme list moves.
xcodebuild -resolvePackageDependencies -project "$PROJECT"

# A silent no-op here ships the failure this script exists to prevent, one step later and with a
# less useful message, so the file is asserted to exist rather than the exit status trusted.
RESOLVED="$REPO/Packages/Granita/Package.resolved"
if [ ! -f "$RESOLVED" ]; then
    echo "error: resolution wrote no $RESOLVED — has the package layout moved?" >&2
    exit 1
fi

echo "note: resolved package dependencies for build ${CI_BUILD_NUMBER}"
