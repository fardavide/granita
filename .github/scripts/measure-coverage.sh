#!/usr/bin/env bash
# Aggregate required suite counters without building or rerunning tests.
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
INPUTS="$ROOT/build/coverage-inputs"
COVERAGE="$ROOT/build/coverage"
TOOLCHAIN="$(xcodebuild -version) $(uname -m)"
REVISION="${GITHUB_SHA:-$(git rev-parse HEAD)}"
RUN="${GITHUB_RUN_ID:-local}:${GITHUB_RUN_ATTEMPT:-1}"
REF="${GITHUB_REF_NAME:-local}"
SOURCE_DIGEST="$(python3 .github/scripts/source_digest.py)"
rm -rf "$COVERAGE"
mkdir -p "$COVERAGE"

for suite in unit ios-0 ios-1 mac; do
    python3 .github/scripts/coverage_artifacts.py "$INPUTS/$suite/manifest.json" "$REVISION" "$RUN" "$TOOLCHAIN" "$SOURCE_DIGEST"
    jq -e --arg suite "$suite" --arg root "$ROOT" '.suite == $suite and .source_root == $root' "$INPUTS/$suite/manifest.json"
    # Artifact transport may rewrite mtimes. Provenance and content hashes above establish
    # compatibility; normalize transport timestamps before LLVM's age heuristic runs.
    touch -r "$INPUTS/$suite/profile.profdata" "$INPUTS/$suite/objects/"*
done
cmp "$INPUTS/ios-0/enumerated-tests.json" "$INPUTS/ios-1/enumerated-tests.json"
python3 .github/scripts/snapshot_shards.py partition "$INPUTS/ios-0/enumerated-tests.json" \
    "$INPUTS/ios-0/planned-tests.json" "$INPUTS/ios-1/planned-tests.json"

UNIT_OBJECTS=()
SNAPSHOT_OBJECTS=()
for object in "$INPUTS/unit/objects/"*; do UNIT_OBJECTS+=(-object "$object"); done
for suite in ios-0 ios-1 mac; do
    for object in "$INPUTS/$suite/objects/"*; do SNAPSHOT_OBJECTS+=(-object "$object"); done
done

xcrun llvm-cov export -arch "$(uname -m)" --check-binary-ids -instr-profile "$INPUTS/unit/profile.profdata" \
    "${UNIT_OBJECTS[@]}" > "$COVERAGE/unit.json" 2> "$COVERAGE/unit-diagnostics.log"
test ! -s "$COVERAGE/unit-diagnostics.log"
python3 .github/scripts/coverage.py collect --category unit --export "$COVERAGE/unit.json" \
    --out "$COVERAGE/summary.json" --ref "$REF"

xcrun llvm-profdata merge -sparse "$INPUTS/ios-0/profile.profdata" "$INPUTS/ios-1/profile.profdata" "$INPUTS/mac/profile.profdata" \
    -o "$COVERAGE/snapshot.profdata"
xcrun llvm-cov export -arch "$(uname -m)" --check-binary-ids -instr-profile "$COVERAGE/snapshot.profdata" \
    "${SNAPSHOT_OBJECTS[@]}" > "$COVERAGE/snapshot.json" 2> "$COVERAGE/snapshot-diagnostics.log"
test ! -s "$COVERAGE/snapshot-diagnostics.log"
python3 .github/scripts/coverage.py collect --category snapshot --export "$COVERAGE/snapshot.json" \
    --out "$COVERAGE/summary.json" --ref "$REF"

# Total is the union of unfiltered counters and mappings, never category percentages.
xcrun llvm-profdata merge -sparse "$INPUTS/unit/profile.profdata" \
    "$INPUTS/ios-0/profile.profdata" "$INPUTS/ios-1/profile.profdata" "$INPUTS/mac/profile.profdata" -o "$COVERAGE/all.profdata"
xcrun llvm-cov export -arch "$(uname -m)" --check-binary-ids -instr-profile "$COVERAGE/all.profdata" \
    "${UNIT_OBJECTS[@]}" "${SNAPSHOT_OBJECTS[@]}" > "$COVERAGE/all.json" 2> "$COVERAGE/all-diagnostics.log"
test ! -s "$COVERAGE/all-diagnostics.log"
python3 .github/scripts/coverage.py collect --category all --export "$COVERAGE/all.json" \
    --out "$COVERAGE/summary.json" --ref "$REF"
jq -e '.categories | ([.unit, .snapshot, .all] | all(.[]; .lines.count > 0 and .regions.count > 0))' "$COVERAGE/summary.json"
echo "Wrote $COVERAGE/summary.json"
