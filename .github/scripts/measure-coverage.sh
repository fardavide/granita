#!/usr/bin/env bash
# Measure line and region coverage once per kind of test, and once for everything together.
#
# Three passes, not one: coverage is a property of the tests that ran, so the only way to say what
# the *snapshot* tests reach — as opposed to what the whole suite reaches — is to run them alone and
# read the profile. The kinds are directories, and each directory is its own bundle:
#
#   unit      Packages/Granita/**/…Tests       the package suite, on the host, no simulator
#   ui        Apps/GranitaMobileUiTests        behavioural tests: render a screen and drive it
#   snapshot  Apps/GranitaMobileSnapshotTests  rendered against a committed baseline, on a simulator
#             Apps/GranitaMacSnapshotTests     …and on this Mac, for the Settings window
#   all       every profile merged, read through every object set
#
# **The snapshot kind is two bundles, one row.** The phone renders on a simulator and the Mac renders
# on the machine itself — there is no macOS simulator — but the question the row answers is the same
# for both: of the code that draws screens, how much does a baseline put on screen. Two rows would
# split a single question along a platform axis that no reader of the report cares about, and would
# make the Mac's row look like a regression on the day it first appears. The two profiles are merged
# before the row is taken, exactly as `all` merges everything.
#
# A kind with no bundle yet is skipped rather than faked, and its row in the report reads "—".
# `ui` is that case today: the first behavioural test brings the target with it.
#
# **Regions, not branches.** swiftc emits no branch coverage — llvm-cov reports `branches: 0/0` for
# every Swift object, dependencies included. `regions` is the near-equivalent it does emit.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PACKAGE="Packages/Granita"
COVERAGE="build/coverage"
OUT="${COVERAGE}/summary.json"
DERIVED="${COVERAGE}/DerivedData"
REF="${GITHUB_REF_NAME:-local}"

rm -rf "$COVERAGE"
mkdir -p "$COVERAGE"

# Xcode instruments the *test bundle* on `-enableCodeCoverage YES` alone; the app and the local
# package targets it links keep no coverage mapping at all, and the export then comes back with zero
# package files and no error to explain it. These two settings are what actually reach every target
# in the graph. Verified by reading `__llvm_covmap` out of the built product.
COVERAGE_SETTINGS=(
    -enableCodeCoverage YES
    ENABLE_CODE_COVERAGE=YES
    CLANG_COVERAGE_MAPPING=YES
)

# ---------------------------------------------------------------------------------------------
# unit — the package suite, on the host
# ---------------------------------------------------------------------------------------------

echo "::group::Coverage — unit"
( cd "$PACKAGE" && swift test --enable-code-coverage )

# SwiftPM writes the llvm-cov export itself and will tell you where — no locating a .profdata and a
# test bundle by hand, and no `xcrun llvm-cov` invocation to keep in step with the toolchain.
UNIT_EXPORT="$(cd "$PACKAGE" && swift test --show-codecov-path)"
if [ ! -f "$UNIT_EXPORT" ]; then
    echo "::error::SwiftPM reported no coverage export at ${UNIT_EXPORT}"
    exit 1
fi

python3 .github/scripts/coverage.py collect \
    --category unit --export "$UNIT_EXPORT" --out "$OUT" --ref "$REF"
echo "::endgroup::"

# The merge below needs the binary the profile was written against. `--show-codecov-path` rebuilds
# if anything is stale, so this is resolved after it: a relinked binary and an older profile produce
# "no coverage data found" rather than a wrong number, but it fails the job either way.
UNIT_PROFILE="${PACKAGE}/.build/arm64-apple-macosx/debug/codecov/default.profdata"
UNIT_BINARY="$(find "${PACKAGE}/.build/arm64-apple-macosx/debug/GranitaPackageTests.xctest" -type f -name GranitaPackageTests | head -1)"

# ---------------------------------------------------------------------------------------------
# snapshot — the iOS suite, on a simulator
# ---------------------------------------------------------------------------------------------

echo "::group::Coverage — snapshot"

# The name is resolved rather than hardcoded: the runner image ships "iPhone 17 Pro" and not a plain
# "iPhone 17", and that has already changed once between releases.
SIMULATOR="$(xcrun simctl list devices available | grep -oE 'iPhone 1[6-9][A-Za-z ]*' | head -1 | sed 's/ *$//')"
if [ -z "$SIMULATOR" ]; then
    echo "::error::No recent iPhone simulator on this machine"
    exit 1
fi
echo "Using ${SIMULATOR}"

# `|| true` deliberately. This pass wants the profile, not the verdict: whether the baselines still
# match is the Snapshot job's question, and one stale PNG failing two jobs tells nobody anything the
# first failure did not. A run that fails outright still leaves counters for whatever executed.
xcodebuild test \
    -project Granita.xcodeproj \
    -scheme GranitaMobile \
    -destination "platform=iOS Simulator,name=${SIMULATOR},OS=latest" \
    -derivedDataPath "$DERIVED" \
    -clonedSourcePackagesDirPath SourcePackages \
    -only-testing:GranitaMobileSnapshotTests \
    "${COVERAGE_SETTINGS[@]}" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet || echo "::warning::The snapshot pass failed; measuring whatever it reached."

SNAPSHOT_PROFILE="$(find "$DERIVED" -name Coverage.profdata | head -1)"
if [ -z "$SNAPSHOT_PROFILE" ]; then
    echo "::error::The snapshot pass wrote no profile — nothing ran, or coverage was not instrumented."
    exit 1
fi

# Every Mach-O the run could have executed. Under Xcode 26 an app's own code lives in
# `Granita.app/Granita.debug.dylib` and the launcher beside it carries no coverage mapping at all —
# passing only the launcher yields an export with zero package files and no error.
PRODUCTS="${DERIVED}/Build/Products/Debug-iphonesimulator"
SNAPSHOT_OBJECTS=()
for candidate in \
    "${PRODUCTS}/Granita.app/Granita.debug.dylib" \
    "${PRODUCTS}/Granita.app/Granita" \
    "${PRODUCTS}/Granita.app/PlugIns/GranitaMobileSnapshotTests.xctest/GranitaMobileSnapshotTests"
do
    # Spelled as an `if` rather than `[ … ] && …`: a false test on the last iteration makes the
    # whole `for` return non-zero, and `set -e` would end the run here with no message.
    if [ -f "$candidate" ]; then
        SNAPSHOT_OBJECTS+=(-object "$candidate")
    fi
done
if [ ${#SNAPSHOT_OBJECTS[@]} -eq 0 ]; then
    echo "::error::Found no built product under ${PRODUCTS} to read coverage from"
    exit 1
fi

echo "::endgroup::"

# ---------------------------------------------------------------------------------------------
# snapshot — the macOS half, on this machine
# ---------------------------------------------------------------------------------------------
#
# Its own derived data path, deliberately. The profile below is located by searching for
# `Coverage.profdata`, and two platforms' runs sharing one directory would make `head -1` a coin
# flip between them — which produces a plausible number from the wrong pass.

echo "::group::Coverage — snapshot (macOS)"

MAC_DERIVED="${COVERAGE}/DerivedDataMac"

# `|| true` for the same reason as the iOS pass: this wants the profile, not the verdict.
xcodebuild test \
    -project Granita.xcodeproj \
    -scheme GranitaMac \
    -destination 'platform=macOS' \
    -derivedDataPath "$MAC_DERIVED" \
    -clonedSourcePackagesDirPath SourcePackages \
    -only-testing:GranitaMacSnapshotTests \
    "${COVERAGE_SETTINGS[@]}" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet || echo "::warning::The macOS snapshot pass failed; measuring whatever it reached."

MAC_SNAPSHOT_PROFILE="$(find "$MAC_DERIVED" -name Coverage.profdata | head -1)"
if [ -z "$MAC_SNAPSHOT_PROFILE" ]; then
    echo "::error::The macOS snapshot pass wrote no profile — nothing ran, or coverage was not instrumented."
    exit 1
fi

MAC_PRODUCTS="${MAC_DERIVED}/Build/Products/Debug"
MAC_SNAPSHOT_OBJECTS=()
for candidate in \
    "${MAC_PRODUCTS}/Granita.app/Contents/MacOS/Granita.debug.dylib" \
    "${MAC_PRODUCTS}/Granita.app/Contents/MacOS/Granita" \
    "${MAC_PRODUCTS}/Granita.app/Contents/PlugIns/GranitaMacSnapshotTests.xctest/Contents/MacOS/GranitaMacSnapshotTests"
do
    if [ -f "$candidate" ]; then
        MAC_SNAPSHOT_OBJECTS+=(-object "$candidate")
    fi
done
if [ ${#MAC_SNAPSHOT_OBJECTS[@]} -eq 0 ]; then
    echo "::error::Found no built product under ${MAC_PRODUCTS} to read coverage from"
    exit 1
fi
echo "::endgroup::"

# ---------------------------------------------------------------------------------------------
# snapshot — both halves, merged into one row
# ---------------------------------------------------------------------------------------------

echo "::group::Coverage — snapshot"
xcrun llvm-profdata merge -sparse "$SNAPSHOT_PROFILE" "$MAC_SNAPSHOT_PROFILE" \
    -o "${COVERAGE}/snapshot.profdata"

xcrun llvm-cov export \
    -instr-profile "${COVERAGE}/snapshot.profdata" \
    "${SNAPSHOT_OBJECTS[@]}" \
    "${MAC_SNAPSHOT_OBJECTS[@]}" \
    > "${COVERAGE}/snapshot.json"

python3 .github/scripts/coverage.py collect \
    --category snapshot --export "${COVERAGE}/snapshot.json" --out "$OUT" --ref "$REF"
echo "::endgroup::"

# ---------------------------------------------------------------------------------------------
# all — both profiles merged, read through both object sets
# ---------------------------------------------------------------------------------------------
#
# A union rather than a sum, and it has to be done at the profile level: a line covered by both the
# unit and the snapshot pass is one covered line, and adding the two rows would count it twice.
# `llvm-profdata merge` adds the counters per function, and one `llvm-cov export` over every object
# then resolves them against the mappings — the host binary contributes the server modules the
# simulator never links, the simulator objects contribute the views the host cannot render.

echo "::group::Coverage — all"
xcrun llvm-profdata merge -sparse "$UNIT_PROFILE" "$SNAPSHOT_PROFILE" "$MAC_SNAPSHOT_PROFILE" \
    -o "${COVERAGE}/all.profdata"

xcrun llvm-cov export \
    -instr-profile "${COVERAGE}/all.profdata" \
    "$UNIT_BINARY" \
    "${SNAPSHOT_OBJECTS[@]}" \
    "${MAC_SNAPSHOT_OBJECTS[@]}" \
    > "${COVERAGE}/all.json"

python3 .github/scripts/coverage.py collect \
    --category all --export "${COVERAGE}/all.json" --out "$OUT" --ref "$REF"
echo "::endgroup::"

echo "Wrote ${OUT}"
