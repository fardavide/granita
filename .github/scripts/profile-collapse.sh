#!/usr/bin/env bash
# A separate diagnostic build. Never creates or replaces required coverage receipts.
set -euo pipefail

SIMULATOR="${1:?Expected the selected iPhone simulator name}"
OUT=build/motion-cpu-profile
READY=/private/tmp/granita-ci-collapse-profile-20261026.ready.json
ARMED=/private/tmp/granita-ci-collapse-profile-20261026.armed
test ! -e "$READY"
test ! -e "$ARMED"
mkdir -p "$OUT"

cp .github/diagnostics/ContinuousDiffCpuProfile.swift Apps/GranitaMobileSnapshotTests/ContinuousDiffCpuProfile.swift
make project
python3 .github/scripts/source_digest.py > "$OUT/diagnostic-source-digest.txt"
git rev-parse HEAD > "$OUT/checkout-revision.txt"
make profile-collapse-build-ios IOS_SIM_NAME="$SIMULATOR" XCODE_QUIET=-quiet

tests_pid=
recorder_pid=
cleanup() {
    if [ -n "$recorder_pid" ] && kill -0 "$recorder_pid" 2>/dev/null; then
        kill -INT "$recorder_pid" || true
    fi
    if [ -n "$tests_pid" ] && kill -0 "$tests_pid" 2>/dev/null; then
        kill -TERM "$tests_pid" || true
    fi
}
trap cleanup EXIT

make profile-collapse-capture-ios IOS_SIM_NAME="$SIMULATOR" XCODE_QUIET=-quiet &
tests_pid=$!
ready_deadline=$((SECONDS + 240))
while [ ! -f "$READY" ]; do
    if ! kill -0 "$tests_pid" 2>/dev/null || [ "$SECONDS" -ge "$ready_deadline" ]; then
        echo '::error::The diagnostic test did not publish a fresh process identity'
        exit 1
    fi
    sleep 0.1
done
jq -e '.processId > 0 and .processId == (.processId | floor) and .bundleId == "dev.fardavide.granita.mobile"' "$READY"
cp "$READY" "$OUT/ready.json"
app_pid="$(jq -r '.processId' "$READY")"
app_command="$(ps -p "$app_pid" -o comm=)"
case "$app_command" in
    */CoreSimulator/Devices/*/Granita.app/Granita) ;;
    *) echo "::error::Unexpected diagnostic process: $app_command"; exit 1 ;;
esac

# script supplies the same PTY used by the proven local recording protocol. The
# started banner is a readiness signal: never arm merely because the process exists.
script -qF "$OUT/recorder.log" xcrun xctrace record --template 'Time Profiler' \
    --device "$SIMULATOR" --attach "$app_pid" --time-limit 20s --output "$OUT/collapse.trace" &
recorder_pid=$!
armed_deadline=$((SECONDS + 90))
while [ ! -f "$OUT/recorder.log" ] || ! grep -Fq 'Ctrl-C to stop the recording' "$OUT/recorder.log"; do
    if ! kill -0 "$recorder_pid" 2>/dev/null || [ "$SECONDS" -ge "$armed_deadline" ]; then
        echo '::error::Time Profiler did not report that recording had started'
        exit 1
    fi
    sleep 0.1
done
touch "$ARMED"
if wait "$tests_pid"; then test_result=0; else test_result=$?; fi
tests_pid=
if wait "$recorder_pid"; then recorder_result=0; else recorder_result=$?; fi
recorder_pid=
if [ "$recorder_result" -ne 0 ]; then
    echo "::error::Time Profiler exited with $recorder_result"
    exit "$recorder_result"
fi
xcrun xctrace export --input "$OUT/collapse.trace" --toc --output "$OUT/trace-toc.xml"
xcrun xctrace export --input "$OUT/collapse.trace" \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' \
    --output "$OUT/time-profile.xml"
xcrun xctrace export --input "$OUT/collapse.trace" \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="os-signpost"]' \
    --output "$OUT/signposts.xml"
sample_count="$(xmllint --nonet --xpath 'count(//row)' "$OUT/time-profile.xml")"
test "$sample_count" -gt 0
phases_present="$(xmllint --nonet --xpath 'boolean(//signpost-name[text()="CiPlainCollapse"]) and boolean(//signpost-name[text()="CiDenseCollapse"])' "$OUT/signposts.xml")"
if [ "$phases_present" != true ]; then
    echo '::error::Both diagnostic cases must occur inside the CPU recording'
    exit 1
fi
echo "Diagnostic test exit: $test_result. Required verdict and receipts are unchanged."
exit "$test_result"
