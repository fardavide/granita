#!/bin/sh
# Xcode Cloud custom build script — runs before every xcodebuild action.
#
# Xcode Cloud finds this directory because it sits next to Granita.xcodeproj. The name and location
# are fixed by Apple: `ci_scripts/ci_pre_xcodebuild.sh`, top level, executable bit committed.
#
# It pins both halves of the shipped version to their real sources, because the values inside the
# committed project are placeholders that only `xcodegen generate` is supposed to change:
#
#   CURRENT_PROJECT_VERSION  <- Xcode Cloud's own run number. It assigns each build a monotonically
#       increasing integer, and App Store Connect rejects a CFBundleVersion that repeats within a
#       release train — every build sharing one CFBundleShortVersionString. Without this, every
#       archive would upload as build 1 and every upload after the first would be refused.
#
#   MARKETING_VERSION        <- project.yml, this repository's single source for it. The committed
#       project should already agree, because CI's "Generated files" job regenerates it and fails
#       on any drift — but a version bump that lands without a machine able to run xcodegen would
#       ship mislabelled, and this makes that unshippable rather than merely unlikely.
#
# Info.plist declares both as $(…) references, so rewriting the build settings is enough. agvtool
# is deliberately not used: it requires VERSIONING_SYSTEM = apple-generic, which this project does
# not set, and would silently do nothing.
set -eu

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
    echo "note: CI_BUILD_NUMBER unset — not an Xcode Cloud build, leaving the version alone"
    exit 0
fi

REPO="${CI_PRIMARY_REPOSITORY_PATH:?}"
PBXPROJ="$REPO/Granita.xcodeproj/project.pbxproj"
MANIFEST="$REPO/project.yml"

if [ ! -f "$PBXPROJ" ]; then
    echo "error: no project at $PBXPROJ" >&2
    exit 1
fi
if [ ! -f "$MANIFEST" ]; then
    echo "error: no manifest at $MANIFEST" >&2
    exit 1
fi

MARKETING_VERSION=$(sed -n -E 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*([0-9][0-9.]*).*/\1/p' "$MANIFEST" | head -1)
if [ -z "$MARKETING_VERSION" ]; then
    echo "error: could not read MARKETING_VERSION from $MANIFEST" >&2
    exit 1
fi

sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" "$PBXPROJ"
sed -i '' -E "s/MARKETING_VERSION = [0-9][0-9.]*;/MARKETING_VERSION = ${MARKETING_VERSION};/g" "$PBXPROJ"

# A silent no-op here ships a duplicate build number or a mislabelled release, so assert both
# rewrites landed rather than trusting sed's exit status.
written=$(grep -c "CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};" "$PBXPROJ" || true)
if [ "$written" -lt 1 ]; then
    echo "error: failed to set CURRENT_PROJECT_VERSION — has the pbxproj format changed?" >&2
    exit 1
fi
labelled=$(grep -c "MARKETING_VERSION = ${MARKETING_VERSION};" "$PBXPROJ" || true)
if [ "$labelled" -lt 1 ]; then
    echo "error: failed to set MARKETING_VERSION — has the pbxproj format changed?" >&2
    exit 1
fi

echo "note: shipping ${MARKETING_VERSION} (${labelled} configuration(s)) as build ${CI_BUILD_NUMBER} (${written} configuration(s))"
