#!/usr/bin/env bash
# Run the package suite with coverage instrumentation and fold the result into a summary.
#
# SwiftPM writes an llvm-cov export itself and will tell you where — no locating a .profdata and a
# test bundle by hand, and no `xcrun llvm-cov` invocation to keep in step with the toolchain.
#
# One pass, because there is one test category. Oltre runs five, filtered per category, so it can
# say what the behaviour tests reach as opposed to what the whole suite reaches; that distinction
# needs more than one category to mean anything, and arrives here when the snapshot tests do.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PACKAGE="Packages/Granita"
OUT="build/coverage/summary.json"
REF="${GITHUB_REF_NAME:-local}"

rm -rf build/coverage
mkdir -p build/coverage

echo "::group::Test with coverage"
( cd "$PACKAGE" && swift test --enable-code-coverage )
echo "::endgroup::"

EXPORT="$(cd "$PACKAGE" && swift test --show-codecov-path)"
if [ ! -f "$EXPORT" ]; then
    echo "::error::SwiftPM reported no coverage export at ${EXPORT}"
    exit 1
fi

python3 .github/scripts/coverage.py collect \
    --export "$EXPORT" \
    --out "$OUT" \
    --ref "$REF"

echo "Wrote ${OUT}"
