#!/usr/bin/env bash
# Preserve executable modes and symlinks; transfer products without counters or intermediates.
set -euo pipefail
cd "$(dirname "$0")/../.."
PRODUCTS=build/derived/ios/Build/Products
REVISION="${GITHUB_SHA:-$(git rev-parse HEAD)}"
RUN="${GITHUB_RUN_ID:-local}:${GITHUB_RUN_ATTEMPT:-1}"
TOOLCHAIN="$(xcodebuild -version) $(uname -m)"
ROOT="$(pwd)"
SOURCE_DIGEST="$(python3 .github/scripts/source_digest.py)"
case "${1:?Expected begin, pack or restore}" in
    begin)
        mkdir -p build
        jq -n --arg revision "$REVISION" --arg run "$RUN" --arg toolchain "$TOOLCHAIN" --arg root "$ROOT" --arg source_digest "$SOURCE_DIGEST" \
            '{revision:$revision,run:$run,toolchain:$toolchain,root:$root,source_digest:$source_digest}' > build/ios-build.json
        ;;
    pack)
        test -d "$PRODUCTS"
        python3 .github/scripts/source_digest.py verify-build build/ios-build.json "$REVISION" "$RUN" "$TOOLCHAIN" "$ROOT"
        cp build/ios-build.json "$PRODUCTS/coverage-build.json"
        tar -czf build/ios-test-products.tar.gz -C "$PRODUCTS" .
        ;;
    restore)
        rm -rf build/derived/ios
        mkdir -p "$PRODUCTS"
        tar -xzf build/ios-test-products.tar.gz -C "$PRODUCTS"
        python3 .github/scripts/source_digest.py verify-build "$PRODUCTS/coverage-build.json" "$REVISION" "$RUN" "$TOOLCHAIN" "$ROOT"
        ;;
    *) exit 1 ;;
esac
