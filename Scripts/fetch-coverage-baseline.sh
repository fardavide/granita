#!/usr/bin/env bash
# Fetch the coverage numbers the gate will ratchet this branch against.
#
# **The gate compares against the last `main` run, so that is the only baseline worth measuring
# against locally.** Guessing at it — "the row was 96 point something last week" — is what turned a
# falling row into a CI round trip four times over, and a round trip is twenty minutes to learn a
# number that is already written down.
#
# It fetches the `coverage-summary` artifact rather than `coverage-exports`, which is the same six
# numbers without the ~300 MB of per-file detail beside them. When a row actually falls, THEN pull
# the big one: it is what says which files moved, and reading it is the difference between knowing
# and estimating.
#
#     Scripts/fetch-coverage-baseline.sh [--force]
#
# Writes .coverage-baseline/summary.json, which is gitignored and is where
# `.github/scripts/coverage.py render --baseline` expects it. Existing files are left alone unless
# --force is given, so a repeated `make coverage` costs one API call rather than a download.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPO="fardavide/granita"
BASELINE_DIR=".coverage-baseline"
BASELINE="${BASELINE_DIR}/summary.json"

if [ "${1:-}" != "--force" ] && [ -f "$BASELINE" ]; then
    commit=$(python3 -c "import json;print(json.load(open('${BASELINE}')).get('commit','unknown')[:7])")
    echo "Baseline already present (main @ ${commit}). Pass --force to refresh."
    exit 0
fi

# The most recent *successful* run, not the most recent run: a red one may have written nothing, and
# the gate itself restores by prefix for the same reason.
run=$(gh run list --repo "$REPO" --branch main --workflow CI --status success \
    --limit 1 --json databaseId --jq '.[0].databaseId')
if [ -z "$run" ]; then
    echo "No successful CI run on main to take a baseline from." >&2
    exit 1
fi

echo "Fetching the coverage baseline from main's run ${run}…"
rm -rf "$BASELINE_DIR"
mkdir -p "$BASELINE_DIR"

# A run old enough to predate the `coverage-summary` artifact carries only the big one, so fall back
# to it rather than refusing. That case cures itself at the next `main` run and this stays usable in
# the meantime — including on the very pull request that adds the small artifact, which by
# definition cannot find one on `main` yet.
if ! gh run download "$run" --repo "$REPO" -n coverage-summary -D "$BASELINE_DIR" 2>/dev/null; then
    echo "That run predates the 'coverage-summary' artifact — falling back to the full export."
    echo "It is ~300 MB and only summary.json is kept. The next main run makes this quick."
    big=$(mktemp -d)
    gh run download "$run" --repo "$REPO" -n coverage-exports -D "$big"
    mv "${big}/summary.json" "$BASELINE"
    rm -rf "$big"
fi

python3 -c "
import json
d = json.load(open('${BASELINE}'))
print(f\"Baseline: main @ {d.get('commit','unknown')[:7]}\")
for kind, row in sorted(d['categories'].items()):
    parts = []
    for counter in ('lines', 'regions'):
        n = row[counter]
        parts.append(f\"{counter} {100.0 * n['covered'] / n['count']:.4f}%\")
    print(f\"  {kind:9s} {'  '.join(parts)}\")
"
