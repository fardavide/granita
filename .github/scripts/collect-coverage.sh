#!/usr/bin/env bash
# One required suite, one instrumented execution. Profiles never enter a build cache.
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
SOURCE_DIGEST="$(python3 .github/scripts/source_digest.py)"
SUITE="${1:?Expected unit, ios or mac}"
OUT="${ROOT}/build/coverage-inputs/${SUITE}"
DERIVED="${ROOT}/build/derived/${SUITE}"
rm -rf "$OUT"
mkdir -p "$OUT/objects"
OBJECTS=()

case "$SUITE" in
    unit)
        SCRATCH="${ROOT}/build/derived/package"
        BIN="$(cd Packages/Granita && swift build --show-bin-path --scratch-path "$SCRATCH")"
        rm -rf "$BIN/codecov"
        # pipefail preserves the required test verdict; the receipt also refuses zero-test runs.
        (cd Packages/Granita && swift test --enable-code-coverage --no-parallel --scratch-path "$SCRATCH") | tee "$OUT/tests.log"
        grep -Eq 'Test run with [1-9][0-9]* tests .*passed' "$OUT/tests.log"
        PROFILE="$BIN/codecov/default.profdata"
        for bundle in "$BIN"/*.xctest; do
            candidate="$bundle/Contents/MacOS/$(basename "$bundle" .xctest)"
            if [ -f "$candidate" ]; then OBJECTS+=("$candidate"); fi
        done
        test "$(grep -Ec 'Test run with [1-9][0-9]* tests .*passed' "$OUT/tests.log")" -eq "${#OBJECTS[@]}"
        ;;
    ios|ios-0|ios-1|mac)
        if [ "$SUITE" != mac ]; then DERIVED="${ROOT}/build/derived/ios"; fi
        rm -rf "$DERIVED/Build/ProfileData"
        if [ "$SUITE" != mac ]; then
            SCHEME=GranitaMobile
            TARGET=GranitaMobileSnapshotTests
            SIMULATOR="$(xcrun simctl list devices available | awk '/^-- iOS /{name=""; inios=1; next} /^-- /{inios=0} inios && name=="" && match($0, /iPhone 1[6-9][A-Za-z ]*/){name=substr($0, RSTART, RLENGTH)} END{sub(/ +$/, "", name); print name}')"
            test -n "$SIMULATOR"
            DESTINATION="platform=iOS Simulator,name=${SIMULATOR},OS=latest"
            xcrun simctl boot "$SIMULATOR" || true
            PRODUCTS="$DERIVED/Build/Products/Debug-iphonesimulator/Granita.app"
            CANDIDATES=("$PRODUCTS/Granita.debug.dylib" "$PRODUCTS/Granita" "$PRODUCTS/PlugIns/$TARGET.xctest/$TARGET")
        else
            SCHEME=GranitaMac
            TARGET=GranitaMacSnapshotTests
            DESTINATION=platform=macOS
            PRODUCTS="$DERIVED/Build/Products/Debug/Granita Server.app/Contents"
            CANDIDATES=("$PRODUCTS/MacOS/Granita Server.debug.dylib" "$PRODUCTS/MacOS/Granita Server" "$PRODUCTS/PlugIns/$TARGET.xctest/Contents/MacOS/$TARGET")
        fi
        ACTION=test
        ARGUMENTS=(-project Granita.xcodeproj -scheme "$SCHEME" -only-testing:"$TARGET" -clonedSourcePackagesDirPath SourcePackages)
        if [ "$SUITE" = ios-0 ] || [ "$SUITE" = ios-1 ]; then
            TEST_RUNS=("$DERIVED/Build/Products/"*.xctestrun)
            test "${#TEST_RUNS[@]}" -eq 1
            test -f "${TEST_RUNS[0]}"
            ACTION=test-without-building
            ARGUMENTS=(-xctestrun "${TEST_RUNS[0]}" -only-testing "@${ROOT}/build/ios-shards/shard-${SUITE#ios-}.txt" -parallel-testing-enabled NO)
            cp "$ROOT/build/ios-shards/shard-${SUITE#ios-}.json" "$OUT/planned-tests.json"
            cp "$ROOT/build/ios-test-plan.json" "$OUT/enumerated-tests.json"
        fi
        xcodebuild "$ACTION" "${ARGUMENTS[@]}" \
            -destination "$DESTINATION" -derivedDataPath "$DERIVED" \
            -resultBundlePath "$OUT/tests.xcresult" \
            -enableCodeCoverage YES ENABLE_CODE_COVERAGE=YES CLANG_COVERAGE_MAPPING=YES \
            CODE_SIGNING_ALLOWED=NO
        xcrun xcresulttool get test-results summary --path "$OUT/tests.xcresult" > "$OUT/test-summary.json"
        jq -e '.result == "Passed" and .passedTests > 0 and .totalTestCount == .passedTests and .failedTests == 0 and .skippedTests == 0 and all(.devicesAndConfigurations[]; .failedTests == 0 and .skippedTests == 0)' "$OUT/test-summary.json"
        xcrun xcresulttool get test-results tests --path "$OUT/tests.xcresult" > "$OUT/test-inventory.json"
        if [ -f "$OUT/planned-tests.json" ]; then
            python3 .github/scripts/snapshot_shards.py verify "$OUT/planned-tests.json" "$OUT/test-inventory.json"
        fi
        PROFILES=()
        while IFS= read -r path; do PROFILES+=("$path"); done < <(find "$DERIVED/Build/ProfileData" -name Coverage.profdata)
        if [ "${#PROFILES[@]}" -ne 1 ]; then
            echo "::error::Expected exactly one fresh $SUITE coverage profile, found ${#PROFILES[@]}"
            exit 1
        fi
        PROFILE="${PROFILES[0]}"
        for candidate in "${CANDIDATES[@]}"; do
            test -f "$candidate"
            OBJECTS+=("$candidate")
        done
        ;;
    *) echo "::error::Unknown coverage suite: $SUITE"; exit 1 ;;
esac

test -s "$PROFILE"
test "${#OBJECTS[@]}" -gt 0
cp -p "$PROFILE" "$OUT/profile.profdata"
for index in "${!OBJECTS[@]}"; do cp -p "${OBJECTS[$index]}" "$OUT/objects/object-$index"; done
# Mapping objects, profile and receipt are hashed together. Test bundles retain their compiled
# filenames, so collectors and aggregator must use the same checkout root.
FILES='[]'
RECEIPTS=()
for candidate in "$OUT/tests.log" "$OUT/test-summary.json" "$OUT/test-inventory.json" "$OUT/planned-tests.json" "$OUT/enumerated-tests.json"; do
    if [ -f "$candidate" ]; then RECEIPTS+=("$candidate"); fi
done
for path in "$OUT/profile.profdata" "$OUT"/objects/* "${RECEIPTS[@]}"; do
    digest="$(shasum -a 256 "$path")"
    digest="${digest%% *}"
    FILES="$(jq -c --arg path "${path#"$OUT/"}" --arg sha256 "$digest" '. + [{path: $path, sha256: $sha256}]' <<< "$FILES")"
done
TOOLCHAIN="$(xcodebuild -version) $(uname -m)"
REVISION="${GITHUB_SHA:-$(git rev-parse HEAD)}"
RUN="${GITHUB_RUN_ID:-local}:${GITHUB_RUN_ATTEMPT:-1}"
CURRENT_SOURCE_DIGEST="$(python3 .github/scripts/source_digest.py)"
test "$CURRENT_SOURCE_DIGEST" = "$SOURCE_DIGEST"
jq -n --arg suite "$SUITE" --arg source_revision "$REVISION" --arg run "$RUN" \
    --arg toolchain "$TOOLCHAIN" --arg source_root "$ROOT" --arg source_digest "$SOURCE_DIGEST" --argjson files "$FILES" \
    '{schema: 1, complete: true, suite: $suite, source_revision: $source_revision,
      run: $run, toolchain: $toolchain, source_root: $source_root, source_digest: $source_digest, files: $files}' > "$OUT/manifest.json"
