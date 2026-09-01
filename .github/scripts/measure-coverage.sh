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

ROOT="$(pwd)"
PACKAGE="Packages/Granita"
COVERAGE="build/coverage"
OUT="${COVERAGE}/summary.json"
REF="${GITHUB_REF_NAME:-local}"

# **Every build directory below sits outside `build/coverage`, which the wipe further down empties,
# and that placement is the point.** Each pass here is a full build — the package, the iOS app, the
# Mac app — and while they sat beside the exports, every local run paid for all three from cold on a
# machine that had just built the same tree. Measured on the 1 September 2026 `main` run, the two
# app builds alone were 4m20s of a 20m30s job. On a fresh runner these start empty either way, so
# nothing about the numbers changes; on a developer's machine they now stay warm between runs.
#
# What must NOT survive a run is the profile. Both app passes locate theirs by searching the tree
# for `Coverage.profdata` and taking the first hit, so a directory left by an earlier run turns that
# search into a coin flip between this run's numbers and last week's — a plausible number from the
# wrong pass, which is the one failure mode worse than a slow job. Xcode writes exactly one, under
# `Build/ProfileData/<device>/`, so deleting that subtree keeps the search unambiguous and leaves
# the compiled products in place.
DERIVED="${ROOT}/build/derived/ios"
MAC_DERIVED="${ROOT}/build/derived/mac"

# The package's scratch path, deliberately not the `.build` that `make test` uses. Coverage adds
# instrumentation to every swiftc invocation, so the two cannot share a directory without each
# invalidating the other, and alternating the two commands in one working copy rebuilt the package
# from scratch every time. Two directories, two warm builds, at the cost of some disk.
SCRATCH="${ROOT}/build/derived/package"

rm -rf "$COVERAGE"
mkdir -p "$COVERAGE"
rm -rf "${DERIVED}/Build/ProfileData" "${MAC_DERIVED}/Build/ProfileData"

# The package's profile has the same requirement and a nastier version of it: SwiftPM merges *every*
# `.profraw` sitting in `codecov/` into `default.profdata`, so a raw counter file left by an earlier
# run of an earlier commit would be added to this run's numbers — coverage credited to lines that
# this commit's tests never executed, and possibly to lines it no longer has. Harmless while the
# directory was rebuilt from nothing every time; the moment it is kept warm, this is what keeps the
# number honest. The glob covers whichever architecture triple the host builds under.
rm -rf "${SCRATCH}"/*/debug/codecov

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
# the simulator — booted here, used three passes later
# ---------------------------------------------------------------------------------------------
#
# **Started now and waited for later, because a cold boot costs minutes and nothing else needs the
# device.** Left to `xcodebuild`, the boot happens after its build finishes and the whole job simply
# stops for it: on the 1 September 2026 `main` run the iOS pass reported 8m49s for a suite whose
# test bodies account for 5m30s, and the sibling snapshot job — same commit, same suite, unluckier
# runner — showed a 9m31s gap between the app bundle being touched and the app's first log line.
# Booting it against the unit pass, which needs no simulator at all, hides that behind work that had
# to happen anyway. On a developer's machine the device is usually booted already and this returns
# at once.
#
# The name is resolved rather than hardcoded: the runner image ships "iPhone 17 Pro" and not a plain
# "iPhone 17", and that has already changed once between releases.
SIMULATOR="$(xcrun simctl list devices available | grep -oE 'iPhone 1[6-9][A-Za-z ]*' | head -1 | sed 's/ *$//')"
if [ -z "$SIMULATOR" ]; then
    echo "::error::No recent iPhone simulator on this machine"
    exit 1
fi
echo "Using ${SIMULATOR}"

# `bootstatus -b` boots the device if it is shut down and returns once it is ready, which is the
# single call that expresses "have this usable by the time I ask". Backgrounded, and its failure is
# swallowed on purpose: this is an optimisation, and `xcodebuild` boots the device itself if the
# head start did not happen. Turning a warm-up into a job failure would trade minutes for red runs.
xcrun simctl bootstatus "$SIMULATOR" -b > /dev/null 2>&1 &
BOOT_PID=$!

# ---------------------------------------------------------------------------------------------
# unit — the package suite, on the host
# ---------------------------------------------------------------------------------------------

echo "::group::Coverage — unit"
# **Serial, and that is about the measurement rather than about the tests.** Run in parallel, this
# suite reports a different number for identical code: measured on 24 August 2026 over five runs of
# one commit, the unit row came back 96.121% twice and 96.037% three times, and an earlier set moved
# `SessionTranscript` by five lines and `BonjourBrowser` by four. The gate is a plain ratchet with no
# slack, so a pull request that added nothing can fail on the sample it happened to draw — which
# happened, to #35, and a re-run of the same commit passed.
#
# What varies is which lines a scheduler got to before something was torn down, not what the tests
# assert: `swift test` is green either way. Serialising makes the pass measure the suite instead of
# the machine, and it costs about ten seconds on a job that already runs the suite four times.
( cd "$PACKAGE" && swift test --enable-code-coverage --no-parallel --scratch-path "$SCRATCH" )

# SwiftPM writes the llvm-cov export itself and will tell you where — no locating a .profdata and a
# test bundle by hand, and no `xcrun llvm-cov` invocation to keep in step with the toolchain. The
# scratch path has to be repeated: without it this reports the default `.build` location, which is
# where `make test` builds and therefore holds no coverage export at all.
UNIT_EXPORT="$(cd "$PACKAGE" && swift test --show-codecov-path --scratch-path "$SCRATCH")"
if [ ! -f "$UNIT_EXPORT" ]; then
    echo "::error::SwiftPM reported no coverage export at ${UNIT_EXPORT}"
    exit 1
fi

python3 .github/scripts/coverage.py collect \
    --category unit --export "$UNIT_EXPORT" --out "$OUT" --ref "$REF"
# Kept beside the other two so the job can upload all three. A row that falls is diagnosed by
# reading the per-file export and nothing else — this repository has three recorded instances of
# algebra reaching the wrong conclusion about which files moved a number, and the export settles in
# one read what estimating kept getting wrong. Without this the only copy is on a runner that is
# thrown away, and the same question has to be re-asked by pushing another commit.
cp "$UNIT_EXPORT" "${COVERAGE}/unit.json"
echo "::endgroup::"

# The merge below needs the binary the profile was written against. `--show-codecov-path` rebuilds
# if anything is stale, so this is resolved after it: a relinked binary and an older profile produce
# "no coverage data found" rather than a wrong number, but it fails the job either way.
UNIT_PROFILE="${SCRATCH}/arm64-apple-macosx/debug/codecov/default.profdata"
UNIT_BINARY="$(find "${SCRATCH}/arm64-apple-macosx/debug/GranitaPackageTests.xctest" -type f -name GranitaPackageTests | head -1)"

# ---------------------------------------------------------------------------------------------
# snapshot — the iOS suite, on a simulator
# ---------------------------------------------------------------------------------------------

echo "::group::Coverage — snapshot"

# Collect the boot started before the unit pass. `|| true` for the reason given there: a device that
# refused to warm up is `xcodebuild`'s problem to solve, slowly, not a reason to fail the job here.
wait "$BOOT_PID" || echo "::warning::${SIMULATOR} did not finish booting ahead of time; xcodebuild will boot it."

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
