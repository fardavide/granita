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

# **Asked of SwiftPM, never spelled out.** Xcode 26's SwiftPM put products under
# `<scratch>/arm64-apple-macosx/debug` and linked every test target into one `GranitaPackageTests`
# bundle. Xcode 27's builds through Swift Build, which puts them under `<scratch>/out/Products/Debug`
# with one bundle per test target, and the hardcoded path failed the job with nothing but a `find`
# error. The coverage export, its profile and every test bundle all sit under this one directory in
# both layouts. `--show-bin-path` only prints the path; it does not build anything.
UNIT_BIN="$(cd "$PACKAGE" && swift build --show-bin-path --scratch-path "$SCRATCH")"

rm -rf "$COVERAGE"
mkdir -p "$COVERAGE"
rm -rf "${DERIVED}/Build/ProfileData" "${MAC_DERIVED}/Build/ProfileData"

# The package's profile has the same requirement and a nastier version of it: SwiftPM merges *every*
# `.profraw` sitting in `codecov/` into `default.profdata`, so a raw counter file left by an earlier
# run of an earlier commit would be added to this run's numbers — coverage credited to lines that
# this commit's tests never executed, and possibly to lines it no longer has. Harmless while the
# directory was rebuilt from nothing every time; the moment it is kept warm, this is what keeps the
# number honest.
rm -rf "${UNIT_BIN}/codecov"

# Xcode instruments the *test bundle* on `-enableCodeCoverage YES` alone; the app and the local
# package targets it links keep no coverage mapping at all, and the export then comes back with zero
# package files and no error to explain it. These two settings are what actually reach every target
# in the graph. Verified by reading `__llvm_covmap` out of the built product.
COVERAGE_SETTINGS=(
    -enableCodeCoverage YES
    ENABLE_CODE_COVERAGE=YES
    CLANG_COVERAGE_MAPPING=YES
)

# **Empty on purpose: these two passes are not `-quiet`.** That flag makes a working xcodebuild and a
# blocked one produce identical output — nothing at all — so the only way to tell them apart is to go
# looking for the test host process by hand. Each pass here renders hundreds of screens on a
# serialized simulator and takes over ten minutes; with no progress a healthy run is indistinguishable
# from one that has stopped, which is how a clipboard read that blocked forever went undiagnosed for
# hours. Set it back on a runner whose log size is the problem: `XCODE_QUIET=-quiet`.
XCODE_QUIET="${XCODE_QUIET:-}"

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

# **The export is ours, not SwiftPM's.** Under Xcode 26, `swift test --show-codecov-path` pointed at
# an export SwiftPM wrote over its one test bundle, and this row read it. Under Xcode 27, SwiftPM
# builds one bundle per test target and exports only one of them: 98 files where `main` had 1,385,
# so the row measured a tenth of the package and reported a fall that was nothing but the sample
# shrinking. So the export is taken the way the other two rows take theirs, one `llvm-cov export`
# over every bundle against SwiftPM's merged profile.
#
# The binaries are every test bundle SwiftPM built, however many there are: one under Xcode 26, one per
# test target under Xcode 27. Each links the modules it tests, so a module appears in several; llvm-cov
# merges a function's records across objects rather than counting it twice.
UNIT_PROFILE="${UNIT_BIN}/codecov/default.profdata"
UNIT_OBJECTS=()
for bundle in "${UNIT_BIN}"/*.xctest; do
    executable="${bundle}/Contents/MacOS/$(basename "$bundle" .xctest)"
    if [ -f "$executable" ]; then
        UNIT_OBJECTS+=(-object "$executable")
    fi
done
if [ ! -f "$UNIT_PROFILE" ] || [ ${#UNIT_OBJECTS[@]} -eq 0 ]; then
    echo "::error::Found no unit profile or test bundle under ${UNIT_BIN}"
    exit 1
fi

# Written straight into `build/coverage`, where the job uploads it. A row that falls is diagnosed by
# reading the per-file export and nothing else: this repository has three recorded cases of
# arithmetic reaching the wrong conclusion about which files moved a number, and one read of the
# export settles it. Without it, the only copy is on a runner that gets thrown away.
xcrun llvm-cov export -instr-profile "$UNIT_PROFILE" "${UNIT_OBJECTS[@]}" > "${COVERAGE}/unit.json"

python3 .github/scripts/coverage.py collect \
    --category unit --export "${COVERAGE}/unit.json" --out "$OUT" --ref "$REF"
echo "::endgroup::"

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

# **Booted here rather than earlier, and that boundary was paid for.** A cold boot costs minutes, so
# the first version of this started it before the unit pass to hide it behind work that had to happen
# anyway. On the runner that was a straight loss: booting a simulator alongside the package build
# starved it, and the pass went from 5m27s to 15m16s with the suite's own wall time doubling from 25s
# to 50.3s — measured on this script's first run, #62. **The unit pass is `--no-parallel` precisely
# because its coverage number moves with how busy the machine is**, so putting a booting simulator
# beside it threatens the measurement and not just the clock.
#
# What is left is the overlap that costs nothing: the boot runs against `xcodebuild`'s own build of
# the app below, which needs no device until it starts testing. `boot` returns as soon as
# CoreSimulator has taken the request rather than waiting for the device, which is what makes this a
# head start instead of a stall. It fails when the device is already booted — the outcome wanted
# anyway — and if it fails for any other reason `xcodebuild` boots the device itself.
xcrun simctl boot "$SIMULATOR" || true

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
    ${XCODE_QUIET} || echo "::warning::The snapshot pass failed; measuring whatever it reached."

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
    ${XCODE_QUIET} || echo "::warning::The macOS snapshot pass failed; measuring whatever it reached."

MAC_SNAPSHOT_PROFILE="$(find "$MAC_DERIVED" -name Coverage.profdata | head -1)"
if [ -z "$MAC_SNAPSHOT_PROFILE" ]; then
    echo "::error::The macOS snapshot pass wrote no profile — nothing ran, or coverage was not instrumented."
    exit 1
fi

MAC_PRODUCTS="${MAC_DERIVED}/Build/Products/Debug"
# **`Granita Server`, with the space, since issue #73 gave the Client a Mac destination of its own.**
# Two targets cannot both produce `Granita.app` in one products directory, so the menu bar app took
# the name that says which half it is. This is the third place the old spelling was written out rather
# than derived, and none of the three fails until it is run — so if this ever reports finding no
# product, check `PRODUCT_NAME` in project.yml before anything else.
MAC_SNAPSHOT_OBJECTS=()
for candidate in \
    "${MAC_PRODUCTS}/Granita Server.app/Contents/MacOS/Granita Server.debug.dylib" \
    "${MAC_PRODUCTS}/Granita Server.app/Contents/MacOS/Granita Server" \
    "${MAC_PRODUCTS}/Granita Server.app/Contents/PlugIns/GranitaMacSnapshotTests.xctest/Contents/MacOS/GranitaMacSnapshotTests"
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
    "${UNIT_OBJECTS[@]}" \
    "${SNAPSHOT_OBJECTS[@]}" \
    "${MAC_SNAPSHOT_OBJECTS[@]}" \
    > "${COVERAGE}/all.json"

python3 .github/scripts/coverage.py collect \
    --category all --export "${COVERAGE}/all.json" --out "$OUT" --ref "$REF"
echo "::endgroup::"

echo "Wrote ${OUT}"
