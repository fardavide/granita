#!/usr/bin/env bash
# Snapshot baselines are recorded on iOS 27.0. A newer installed runtime is not interchangeable.
set -euo pipefail

DEVICE="$(xcrun simctl list devices available | awk -v requested="${1:-}" '
    /^-- / { baseline = ($0 == "-- iOS 27.0 --") }
    baseline && device == "" && match($0, /iPhone 1[6-9][A-Za-z ]*/) {
        name = substr($0, RSTART, RLENGTH)
        sub(/ +$/, "", name)
        if (requested != "" && name != requested) next
        if (match($0, /\([[:xdigit:]-]+\)/)) {
            device = substr($0, RSTART + 1, RLENGTH - 2)
        }
    }
    END { print device }
')"
if [ -z "$DEVICE" ]; then
    echo "No supported iPhone simulator on the required iOS 27.0 baseline runtime${1:+ named $1}" >&2
    exit 1
fi
printf '%s\n' "$DEVICE"
