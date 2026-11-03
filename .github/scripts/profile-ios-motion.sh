#!/usr/bin/env bash
# Temporary diagnostics only. Nothing here supplies a required coverage receipt.
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
SCRIPT="$ROOT/.github/scripts/profile-ios-motion.sh"
PATCH="$ROOT/.github/diagnostics/native-motion-profile.patch"
RECORDING_OPTIONS="$ROOT/.github/diagnostics/native-motion-recording-options.json"
SOURCE=Apps/GranitaMobileSnapshotTests/ContinuousDiffCollapseInteractionTests.swift
VIEW=Packages/Granita/Client/Viewer/Ui/ContinuousDiffView.swift
OUT="$ROOT/build/native-motion-profile"
REVISION="${GITHUB_SHA:-$(git rev-parse HEAD)}"
RUN="${GITHUB_RUN_ID:-local}:${GITHUB_RUN_ATTEMPT:-1}"
TOOLCHAIN="$(xcodebuild -version) $(uname -m)"
FULL_SHARD="${3:-NO}"
RECORDER="${4:-CPU}"
case "$FULL_SHARD" in
    NO|YES) ;;
    *) printf 'IOS_PROFILE_FULL_SHARD must be NO or YES.\n' >&2; exit 1 ;;
esac
case "$RECORDER" in
    CPU|VIDEO) ;;
    *) printf 'IOS_PROFILE_RECORDER must be CPU or VIDEO.\n' >&2; exit 1 ;;
esac

verify_build() {
    python3 .github/scripts/source_digest.py verify-build build/ios-build.json "$REVISION" "$RUN" "$TOOLCHAIN" "$ROOT"
}

stop_owned_tree() {
    local owned_pid="$1" child_pid
    if ! kill -0 "$owned_pid" 2>/dev/null; then return; fi
    for child_pid in $(pgrep -P "$owned_pid" || true); do
        stop_owned_tree "$child_pid"
    done
    kill -INT "$owned_pid" 2>/dev/null || true
    local attempts=0
    while kill -0 "$owned_pid" 2>/dev/null && (( attempts < 50 )); do
        sleep 0.1
        attempts=$((attempts + 1))
    done
    if kill -0 "$owned_pid" 2>/dev/null; then
        kill -TERM "$owned_pid" 2>/dev/null || true
        attempts=0
        while kill -0 "$owned_pid" 2>/dev/null && (( attempts < 50 )); do
            sleep 0.1
            attempts=$((attempts + 1))
        done
        kill -KILL "$owned_pid" 2>/dev/null || true
    fi
}

case "${1:?Expected all, capture or verify}" in
verify)
    verify_build
    ;;
all)
    test ! -e "$OUT"
    available_kib=$(df -k "$ROOT" | tail -1 | tr -s ' ' | cut -d ' ' -f 4)
    if [[ ! "$available_kib" =~ ^[0-9]+$ ]] || (( available_kib < 8388608 )); then
        printf 'At least 8 GiB of free space is required before profiling.\n' >&2
        exit 1
    fi
    mkdir -p "$OUT"
    git diff --exit-code -- "$SOURCE" "$VIEW"
    python3 .github/scripts/source_digest.py > "$OUT/source-before.txt"
    git rev-parse HEAD > "$OUT/checkout-revision.txt"
    shasum -a 256 "$PATCH" > "$OUT/instrumentation.sha256"
    cp "$PATCH" "$OUT/instrumentation.patch"
    cp "$RECORDING_OPTIONS" "$OUT/recording-options.json"
    shasum -a 256 "$RECORDING_OPTIONS" > "$OUT/recording-options.sha256"
    cp Packages/Granita/Package.resolved "$OUT/Package.resolved"
    xcodebuild -version > "$OUT/xcode.txt"
    xcrun swift --version > "$OUT/compiler.txt"
    xcodebuild -showsdks > "$OUT/sdks.txt"
    sw_vers > "$OUT/host-os.txt"
    uname -m > "$OUT/host-architecture.txt"
    xcrun simctl list devices available --json > "$OUT/devices.json"
    xcrun simctl list runtimes --json > "$OUT/runtimes.json"
    jq -n --arg revision "$REVISION" --arg run "$RUN" --arg toolchain "$TOOLCHAIN" --arg root "$ROOT" --arg full_shard "$FULL_SHARD" --arg recorder "$RECORDER" \
        '{diagnostic_only:true,source_revision:$revision,run:$run,toolchain:$toolchain,source_root:$root,full_shard_1:($full_shard == "YES"),recorder:$recorder}' > "$OUT/provenance.json"
    PATCH_APPLIED=false
    cp -p "$SOURCE" "$OUT/original-interaction-source.swift"
    cp -p "$VIEW" "$OUT/original-view-source.swift"
    CAPTURE_PID=
    cleanup_all() {
        local status=$?
        trap - EXIT INT TERM
        if [[ -n "$CAPTURE_PID" ]]; then
            kill -TERM "$CAPTURE_PID" 2>/dev/null || true
            wait "$CAPTURE_PID" 2>/dev/null || true
        fi
        if [[ "$PATCH_APPLIED" == true ]]; then
            if cmp -s "$SOURCE" "$OUT/instrumented-interaction-source.swift" && cmp -s "$VIEW" "$OUT/instrumented-view-source.swift"; then
                mv -f "$OUT/original-interaction-source.swift" "$SOURCE"
                mv -f "$OUT/original-view-source.swift" "$VIEW"
                python3 .github/scripts/source_digest.py > "$OUT/source-restored.txt"
                if ! cmp -s "$OUT/source-before.txt" "$OUT/source-restored.txt"; then
                    printf 'Diagnostic cleanup did not restore the original source fingerprint.\n' >&2
                    status=1
                fi
            else
                printf 'Instrumented sources changed unexpectedly; original copies are retained for recovery.\n' >&2
                status=1
            fi
        fi
        printf '%s\n' "$status" > "$OUT/diagnostic-exit-status.txt"
        find "$OUT" -type f ! -name artifacts.sha256 -print0 | xargs -0 shasum -a 256 > "$OUT/artifacts.sha256"
        exit "$status"
    }
    trap cleanup_all EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    git apply --recount --check "$PATCH"
    git apply --recount "$PATCH"
    PATCH_APPLIED=true
    cp -p "$SOURCE" "$OUT/instrumented-interaction-source.swift"
    cp -p "$VIEW" "$OUT/instrumented-view-source.swift"
    python3 .github/scripts/source_digest.py > "$OUT/source-instrumented.txt"
    git diff --binary -- "$SOURCE" "$VIEW" > "$OUT/applied-instrumentation.patch"

    # The same instrumented build as required CI, but fresh on this separate runner.
    make coverage-ios-build
    verify_build
    cp build/ios-build.json "$OUT/build-stamp.json"
    cmp "$OUT/source-instrumented.txt" <(python3 .github/scripts/source_digest.py)
    mkdir "$OUT/objects"
    PRODUCT=build/derived/ios/Build/Products/Debug-iphonesimulator/Granita.app
    plutil -convert json -o "$OUT/app-build-info.json" "$PRODUCT/Info.plist"
    for object in "$PRODUCT/Granita" "$PRODUCT/Granita.debug.dylib" "$PRODUCT/PlugIns/GranitaMobileSnapshotTests.xctest/GranitaMobileSnapshotTests"; do
        test -f "$object"
        cp -p "$object" "$OUT/objects/$(basename "$object")"
        xcrun dwarfdump --uuid "$object" >> "$OUT/object-uuids.txt"
    done
    simulator=$(jq -er --arg name "${2:?Expected simulator name}" --slurpfile runtimes "$OUT/runtimes.json" '
        [.devices | to_entries[] | . as $group |
         $runtimes[0].runtimes[] |
         select(.isAvailable and (.identifier | startswith("com.apple.CoreSimulator.SimRuntime.iOS-"))) |
         select(.identifier == $group.key) | . as $runtime |
         $group.value[] | select(.isAvailable and .name == $name) |
         {device:.,runtime:$runtime}] |
        sort_by(.runtime.version | split(".") | map(tonumber)) | last | .device.udid | select(type == "string")
    ' "$OUT/devices.json")
    printf '%s\n' "$simulator" > "$OUT/simulator-udid.txt"
    # Finish cold simulator setup before the diagnostic app's readiness budget starts.
    xcrun simctl bootstatus "$simulator" -b > "$OUT/simulator-boot.txt"
    xcrun xctrace list devices > "$OUT/instruments-devices.txt"
    if [[ "$FULL_SHARD" == YES ]]; then
        make coverage-ios-enumerate coverage-ios-plan "IOS_SIM=platform=iOS Simulator,id=$simulator"
        python3 .github/scripts/snapshot_shards.py partition build/ios-test-plan.json \
            build/ios-shards/shard-0.json build/ios-shards/shard-1.json
        cp build/ios-test-plan.json "$OUT/enumerated-tests.json"
        cp -R build/ios-shards "$OUT/shards"
        jq -e --arg selector 'GranitaMobileSnapshotTests/ContinuousDiffCollapseInteractionTests/`given wide files when a later file is selected then the viewport visibly animates to its header`()' \
            'index($selector) != null and all(.[]; (contains("temporaryDenseCollapseCpuProfile") or contains("temporarySelectorCpuProfile")) | not)' \
            "$OUT/shards/shard-1.json"
    fi
    bash "$SCRIPT" capture "$simulator" "$FULL_SHARD" "$RECORDER" &
    CAPTURE_PID=$!
    capture_status=0
    wait "$CAPTURE_PID" || capture_status=$?
    CAPTURE_PID=
    cmp "$OUT/source-instrumented.txt" <(python3 .github/scripts/source_digest.py)
    exit "$capture_status"
    ;;
capture)
    scenario=selector
    marker=SelectorCapture
    capture_case=selector
    if [[ "$FULL_SHARD" == YES ]]; then marker=CollapseCapture; capture_case=viewedWordDiff; fi
    simulator="${2:?Expected simulator UDID}"
    duration=10s
    CASE_OUT="$OUT/$scenario"
    mkdir "$CASE_OUT"
    base="/private/tmp/granita-ci-native-motion-$scenario"
    ready="$base.ready.json"
    armed="$base.armed"
    requested="$base.requested.json"
    pipe="$base.notification"
    notice="dev.fardavide.granita.native-cpu-profile-$scenario"
    for fresh in "$ready" "$armed" "$pipe" "$requested"; do
        if [[ -e "$fresh" ]]; then
            printf 'Diagnostic path is not fresh: %s\n' "$fresh" >&2
            exit 1
        fi
    done
    test_pid= notice_pid= recorder_pid=
    cleanup_capture() {
        local status=$? owned_pid
        trap - EXIT INT TERM
        for owned_pid in "$notice_pid" "$recorder_pid" "$test_pid"; do
            if [[ -n "$owned_pid" ]]; then
                stop_owned_tree "$owned_pid"
                wait "$owned_pid" 2>/dev/null || true
            fi
        done
        if [[ -f "$ready" ]]; then cp -p "$ready" "$CASE_OUT/ready.json" || status=1; fi
        if [[ -f "$armed" ]]; then cp -p "$armed" "$CASE_OUT/armed" || status=1; fi
        rm -f "$ready" "$armed" "$pipe" "$requested" || status=1
        printf '%s\n' "$status" > "$CASE_OUT/capture-exit-status.txt"
        exit "$status"
    }
    trap cleanup_capture EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    jq -n --arg name "$capture_case" '$name' > "$requested"
    cp -p "$requested" "$CASE_OUT/requested.json"
    runs=(build/derived/ios/Build/Products/*.xctestrun)
    test "${#runs[@]}" -eq 1
    test -f "${runs[0]}"
    make profile-ios-motion-test "IOS_PROFILE_XCTESTRUN=$ROOT/${runs[0]}" \
        "IOS_PROFILE_FULL_SHARD=$FULL_SHARD" "IOS_PROFILE_RESULT=$CASE_OUT/tests.xcresult" \
        "IOS_SIM=platform=iOS Simulator,id=$simulator" &
    test_pid=$!
    deadline=$((SECONDS + 600))
    while [[ ! -s "$ready" ]]; do
        if ! kill -0 "$test_pid" 2>/dev/null; then
            wait "$test_pid"
            printf 'Diagnostic ended without a ready PID.\n' >&2
            exit 1
        fi
        if (( SECONDS >= deadline )); then
            printf 'Diagnostic app did not report readiness.\n' >&2
            exit 1
        fi
        sleep 0.1
    done
    app_pid=$(jq -er --arg capture_case "$capture_case" '
        select(.bundleId == "dev.fardavide.granita.mobile" and .caseName == $capture_case) |
        .processId | select(type == "number" and . > 0 and floor == .)
    ' "$ready")
    app_command=$(ps -p "$app_pid" -o comm=)
    case "$app_command" in
        *CoreSimulator/Devices/"$simulator"/*/Granita.app/Granita) ;;
        *) printf 'Ready PID is not the expected simulator app: %s\n' "$app_command" >&2; exit 1 ;;
    esac
    printf '%s\n' "$app_command" > "$CASE_OUT/verified-app-command.txt"
    recorder_status=0
    if [[ "$RECORDER" == VIDEO ]]; then
        jq -n --argjson pid "$app_pid" --arg simulator "$simulator" \
            '{process_id:$pid,simulator:$simulator,template:"simctl recordVideo",codec:"h264",capture_seconds:10,armed_after:"first native video frame processed",cpu_profiler:false}' > "$CASE_OUT/recording.json"
        python3 .github/scripts/record_ios_video.py "$armed" "$CASE_OUT/motion.mp4" "$simulator" &
        recorder_pid=$!
    else
    jq -n --argjson pid "$app_pid" --arg simulator "$simulator" --arg marker "$marker" --arg duration "$duration" \
        '{process_id:$pid,simulator:$simulator,marker:$marker,template:"Time Profiler",record_waiting_threads:true,time_limit:$duration}' > "$CASE_OUT/recording.json"
    mkfifo "$pipe"
    notifyutil -1 "$notice" > "$pipe" &
    notice_pid=$!
    xcrun xctrace record --no-prompt --template 'Time Profiler' --recording-options "$RECORDING_OPTIONS" --device "$simulator" --attach "$app_pid" \
        --time-limit "$duration" --notify-tracing-started "$notice" --output "$CASE_OUT/cpu.trace" &
    recorder_pid=$!
    if read -r -t 120 notification < "$pipe"; then
        wait "$notice_pid"
        notice_pid=
        printf '%s\n' "$notification" > "$CASE_OUT/recording-started.txt"
        touch "$armed"
    else
        printf 'CPU recorder did not confirm it had started.\n' >&2
        exit 1
    fi
    fi
    wait "$recorder_pid" || recorder_status=$?
    recorder_pid=
    test_status=0
    wait "$test_pid" || test_status=$?
    test_pid=
    jq -n --argjson recorder "$recorder_status" --argjson test "$test_status" \
        '{recorder_exit_status:$recorder,test_exit_status:$test}' > "$CASE_OUT/status.json"
    xcrun xcresulttool get test-results summary --path "$CASE_OUT/tests.xcresult" > "$CASE_OUT/test-summary.json"
    xcrun xcresulttool get test-results tests --path "$CASE_OUT/tests.xcresult" > "$CASE_OUT/test-inventory.json"
    if [[ "$RECORDER" == VIDEO ]]; then
        test -s "$CASE_OUT/motion.mp4"
        if [[ "$FULL_SHARD" == YES ]]; then
            xcrun xcresulttool export attachments --path "$CASE_OUT/tests.xcresult" \
                --output-path "$CASE_OUT/video-phases" --filter 'native-collapse-phase-viewed-wordDiff*'
            phase=$(jq -er '[.[].attachments[] | select(.arguments == [".viewed", ".wordDiff"]) | .exportedFileName] |
                if length == 1 then .[0] else error("Expected exactly one viewed/wordDiff phase") end' "$CASE_OUT/video-phases/manifest.json")
            cp -p "$CASE_OUT/video-phases/$phase" "$CASE_OUT/video-phase.json"
        else
            xcrun xcresulttool export attachments --path "$CASE_OUT/tests.xcresult" \
                --output-path "$CASE_OUT/video-phases" --filter 'native-selector-phase*'
            phase=$(jq -er '[.[].attachments[] | .exportedFileName] |
                if length == 1 then .[0] else error("Expected exactly one selector phase") end' "$CASE_OUT/video-phases/manifest.json")
            cp -p "$CASE_OUT/video-phases/$phase" "$CASE_OUT/video-phase.json"
        fi
        jq -e --slurpfile phase "$CASE_OUT/video-phase.json" '
            .clock_implementation == "mach_absolute_time()" and
            .first_frame_reported <= $phase[0].started.monotonic and
            $phase[0].started.monotonic < $phase[0].ended.monotonic and
            $phase[0].ended.monotonic <= .stop_requested and
            .stop_requested <= .finalized
        ' "$CASE_OUT/motion.recording.json"
    else
    xcrun xctrace export --input "$CASE_OUT/cpu.trace" --toc --output "$CASE_OUT/toc.xml"
    xcrun xctrace export --input "$CASE_OUT/cpu.trace" \
        --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' --output "$CASE_OUT/time-profile.xml"
    xcrun xctrace export --input "$CASE_OUT/cpu.trace" \
        --xpath '/trace-toc/run[@number="1"]/data/table[@schema="os-signpost"]' --output "$CASE_OUT/signposts.xml"
    # Refuse an empty recording. Phase begin/end and exact sample correlation remain inspectable.
    test "$(xmllint --nonet --xpath 'count(//table[@schema="time-profile" and @record-waiting-threads="1"])' "$CASE_OUT/toc.xml")" -gt 0
    test "$(xmllint --nonet --xpath 'count(//table[@schema="time-sample" and @all-thread-states="YES"])' "$CASE_OUT/toc.xml")" -gt 0
    test "$(xmllint --nonet --xpath 'count(//row)' "$CASE_OUT/time-profile.xml")" -gt 0
    marker_id=$(xmllint --nonet --xpath "string((//signpost-name[@fmt='$marker']/@id)[1])" "$CASE_OUT/signposts.xml")
    begin_id=$(xmllint --nonet --xpath 'string((//event-type[@fmt="Begin"]/@id)[1])' "$CASE_OUT/signposts.xml")
    end_id=$(xmllint --nonet --xpath 'string((//event-type[@fmt="End"]/@id)[1])' "$CASE_OUT/signposts.xml")
    test -n "$marker_id"
    test -n "$begin_id"
    test -n "$end_id"
    test "$(xmllint --nonet --xpath "count(//row[(signpost-name[@id='$marker_id'] or signpost-name[@ref='$marker_id']) and (event-type[@id='$begin_id'] or event-type[@ref='$begin_id'])])" "$CASE_OUT/signposts.xml")" -gt 0
    test "$(xmllint --nonet --xpath "count(//row[(signpost-name[@id='$marker_id'] or signpost-name[@ref='$marker_id']) and (event-type[@id='$end_id'] or event-type[@ref='$end_id'])])" "$CASE_OUT/signposts.xml")" -gt 0
    fi
    if [[ "$FULL_SHARD" == YES ]]; then
        jq -e '.totalTestCount > 0 and .totalTestCount == (.passedTests + .failedTests) and .skippedTests == 0' "$CASE_OUT/test-summary.json"
        jq 'map(split("/")[1:] | join("/")) | sort' "$OUT/shards/shard-1.json" > "$CASE_OUT/expected-case-ids.json"
        jq '[.. | objects | select(.nodeType? == "Test Case") | .nodeIdentifier] | sort' "$CASE_OUT/test-inventory.json" > "$CASE_OUT/completed-case-ids.json"
        cmp "$CASE_OUT/expected-case-ids.json" "$CASE_OUT/completed-case-ids.json"
        jq -e 'all(.. | objects | select(.nodeType? == "Test Case" or .nodeType? == "Arguments"); .result == "Passed" or .result == "Failed")' "$CASE_OUT/test-inventory.json"
    else
        jq -e '.totalTestCount == 1 and (.passedTests + .failedTests) == 1 and .skippedTests == 0' "$CASE_OUT/test-summary.json"
    fi
    test "$recorder_status" -eq 0
    test "$test_status" -eq 0
    ;;
*)
    printf 'Expected all, capture or verify.\n' >&2
    exit 1
    ;;
esac
