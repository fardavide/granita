#!/usr/bin/env bash
# Compare identical merged counters with one and two copies of the iOS mappings.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=build/coverage-comparison
mkdir -p "$OUT"
for suite in ios ios-0 ios-1; do
    touch -r "build/coverage-inputs/$suite/profile.profdata" "build/coverage-inputs/$suite/objects/"*
done
xcrun llvm-profdata merge -sparse build/coverage-inputs/ios-{0,1}/profile.profdata -o "$OUT/ios.profdata"
ONE=()
BOTH=()
for object in build/coverage-inputs/ios-0/objects/*; do ONE+=(-object "$object"); done
for object in build/coverage-inputs/ios-{0,1}/objects/*; do BOTH+=(-object "$object"); done
xcrun llvm-cov export -arch "$(uname -m)" -instr-profile "$OUT/ios.profdata" "${ONE[@]}" > "$OUT/one.json"
xcrun llvm-cov export -arch "$(uname -m)" -instr-profile "$OUT/ios.profdata" "${BOTH[@]}" > "$OUT/both.json"
cmp "$OUT/one.json" "$OUT/both.json"
echo 'Duplicate iOS mapping export is byte-identical.'
UNSHARDED=()
for object in build/coverage-inputs/ios/objects/*; do UNSHARDED+=(-object "$object"); done
xcrun llvm-cov export -arch "$(uname -m)" -instr-profile build/coverage-inputs/ios/profile.profdata \
    "${UNSHARDED[@]}" > "$OUT/unsharded.json"
python3 .github/scripts/coverage.py collect --category snapshot --export "$OUT/unsharded.json" --out "$OUT/unsharded-summary.json" --ref comparison
python3 .github/scripts/coverage.py collect --category snapshot --export "$OUT/one.json" --out "$OUT/sharded-summary.json" --ref comparison
cmp "$OUT/unsharded-summary.json" "$OUT/sharded-summary.json"
echo 'Sharded and unsharded iOS snapshot counts and denominators are identical.'
UNIT=()
for object in build/coverage-inputs/unit/objects/*; do UNIT+=(-object "$object"); done
touch -r build/coverage-inputs/unit/profile.profdata build/coverage-inputs/unit/objects/*
xcrun llvm-cov export -arch "$(uname -m)" --check-binary-ids -instr-profile build/coverage-inputs/unit/profile.profdata \
    "${UNIT[@]}" > "$OUT/unit.json" 2> "$OUT/unit-diagnostics.log"
test ! -s "$OUT/unit-diagnostics.log"
python3 .github/scripts/coverage.py collect --category unit --export "$OUT/unit.json" --out "$OUT/unit-summary.json" --ref comparison
jq '{categories:{unit:.categories.unit},ref:"comparison"}' build/coverage-legacy-cold/summary.json > "$OUT/legacy-unit-summary.json"
diff -u "$OUT/legacy-unit-summary.json" "$OUT/unit-summary.json"
echo 'Required unit coverage counts and denominators match the legacy run.'
