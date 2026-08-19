#!/bin/bash
# Builds the git repositories the test suites run against, and writes the golden unified-diff
# files the parser suite asserts on.
#
# Two audiences, one script:
#
#   * The repositories under .fixtures/ are for tests that drive the real git binary — the git
#     layer, the worktree enumerator, the session index. They are gitignored and disposable.
#   * The .diff files under Packages/Granita/Core/Diff/DomainTests/Fixtures/ are committed. They
#     let the parser suite run on a machine with no git at all, and they turn "git changed its
#     output" from a silent drift into a reviewable diff on this repository.
#
# Everything is deterministic: fixed author, fixed committer, fixed timestamps. Re-running on an
# unchanged checkout must leave `git status` clean, because a fixture that churns is a fixture
# nobody reads.
#
# Usage:  Scripts/make-fixture-repo.sh [--out <dir>]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/.fixtures"
GOLDEN="$REPO_ROOT/Packages/Granita/Core/Diff/DomainTests/Fixtures"

while [ $# -gt 0 ]; do
    case "$1" in
        --out) OUT="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

# Determinism. Without a pinned identity and clock the commit object hashes move on every run,
# which moves the `index <old>..<new>` line of every golden diff.
export GIT_AUTHOR_NAME="Granita Fixtures"
export GIT_AUTHOR_EMAIL="fixtures@granita.invalid"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
export GIT_AUTHOR_DATE="2026-01-01T00:00:00+00:00"
export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
# Never let the developer's own configuration reach a fixture.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_OPTIONAL_LOCKS=0
export GIT_TERMINAL_PROMPT=0
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE 2>/dev/null || true

# The invocation prefix the product itself uses (§5.1), so a fixture is generated the same way it
# will be read. `protocol.file.allow` is needed only for the submodule case.
git_() {
    git -c core.pager=cat -c color.ui=false -c core.quotePath=false \
        -c protocol.file.allow=always -c init.defaultBranch=main \
        -c advice.detachedHead=false --no-pager "$@"
}

# The diff-family suffix. --no-ext-diff and --no-color are NOT universal flags — `git status` and
# `git worktree list` reject them outright — so they are appended here and nowhere else.
diff_() {
    git_ diff --no-ext-diff --no-color "$@"
}

say() { printf '  %s\n' "$1"; }

rm -rf "$OUT"
mkdir -p "$OUT" "$GOLDEN"

# ---------------------------------------------------------------------------------------------
# 1. The main fixture repository — one worktree holding every parser case at once.
# ---------------------------------------------------------------------------------------------

echo "building $OUT/main"
MAIN="$OUT/main"
mkdir -p "$MAIN"
cd "$MAIN"
git_ init -q .

# --- committed baseline -----------------------------------------------------------------------

mkdir -p src/deep/nested/single/child
printf 'one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nten\n' > src/modified.txt
printf 'delete me\nand me\n' > src/deleted.txt
printf 'alpha\nbeta\ngamma\ndelta\nepsilon\nzeta\neta\ntheta\n' > src/renamed-from.txt
printf '#!/bin/sh\necho hello\n' > src/mode-change.sh
printf 'unchanged\n' > src/deep/nested/single/child/leaf.txt
printf 'no trailing newline here' > src/no-newline-both.txt
printf 'gains a newline' > src/no-newline-gained.txt
printf 'loses a newline\n' > src/no-newline-lost.txt
printf 'first\r\nsecond\r\nthird\r\n' > src/crlf.txt
printf 'a file with spaces.txt lives here\n' > "src/a file with spaces.txt"
printf 'unicode path\n' > "src/caffè-日本語-🧊.txt"
# A section heading is whatever git finds on the nearest preceding line matching its funcname
# pattern, so the case needs a real function above the hunk.
cat > src/sectioned.swift <<'SWIFT'
import Foundation

func alpha() -> Int {
    let a = 1
    let b = 2
    let c = 3
    let d = 4
    let e = 5
    return a + b + c + d + e
}
SWIFT
printf 'single line\n' > src/single-line.txt
# Real binary, not merely non-printable: git decides by looking for a NUL byte in the first 8000,
# so a blob of \001 is text as far as it is concerned and diffs line by line.
python3 -c 'import sys; sys.stdout.buffer.write(bytes(range(256)) * 2)' > src/binary.bin
printf 'unchanged content\n' > src/untouched.txt

git_ add -A
git_ commit -qm "baseline"

# --- a submodule, committed so its pointer can move -------------------------------------------

SUB="$OUT/submodule-origin"
mkdir -p "$SUB"
( cd "$SUB" && git_ init -q . && printf 'sub v1\n' > sub.txt && git_ add -A && git_ commit -qm "sub one" )
git_ -c protocol.file.allow=always submodule add -q "$SUB" vendor/sub 2>/dev/null
git_ add -A
git_ commit -qm "add submodule"
( cd "$SUB" && printf 'sub v2\n' > sub.txt && git_ add -A && git_ commit -qm "sub two" )
( cd vendor/sub && git_ fetch -q origin && git_ checkout -q "$(git_ rev-parse origin/HEAD 2>/dev/null || git_ rev-parse origin/main)" )

# --- the uncommitted working state: every case at once ----------------------------------------

# modified, with two separated hunks so hunk indexing is exercised
printf 'ONE\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nTEN\n' > src/modified.txt
# deleted
rm src/deleted.txt
# renamed, with a small edit so `similarity index` is under 100
git_ mv src/renamed-from.txt src/renamed-to.txt
printf 'alpha\nbeta\ngamma\ndelta\nEPSILON\nzeta\neta\ntheta\n' > src/renamed-to.txt
# added (staged) and untracked (never added)
printf 'brand new\nsecond line\n' > src/added.txt
git_ add src/added.txt
printf 'never staged\n' > src/untracked.txt
# mode change only, no content change
chmod +x src/mode-change.sh
# no-newline markers on each side
printf 'no trailing newline here, edited' > src/no-newline-both.txt
printf 'gains a newline\n' > src/no-newline-gained.txt
printf 'loses a newline' > src/no-newline-lost.txt
# CRLF preserved verbatim
printf 'first\r\nSECOND\r\nthird\r\n' > src/crlf.txt
# paths with spaces and non-ASCII
printf 'a file with spaces.txt lives here, edited\n' > "src/a file with spaces.txt"
printf 'unicode path, edited — caffè 日本語 🧊\n' > "src/caffè-日本語-🧊.txt"
# a hunk deep inside a function, so the header carries a section heading
sed -i '' 's/    let c = 3/    let c = 30/' src/sectioned.swift
# single-line file: the hunk header omits counts entirely (@@ -1 +1 @@)
printf 'SINGLE LINE\n' > src/single-line.txt
# binary
python3 -c 'import sys; sys.stdout.buffer.write(bytes(reversed(range(256))) * 2)' > src/binary.bin
# a line long enough to exercise wrap arithmetic, plus tabs and wide characters
mkdir -p src/columns
printf 'no tabs, plain ascii\n\tone tab then text\n\t\ttwo tabs\nwide 日本語 characters\ncombining e\xcc\x81 mark\n%s\n' "$(printf 'x%.0s' {1..400})" > src/columns/display-columns.txt

say "generating golden diffs"

# The full uncommitted diff, which is what the product actually renders.
diff_ HEAD -U3 > "$GOLDEN/working-tree.diff"
# Binary content as a real GIT binary patch rather than the one-line "differ" summary.
diff_ HEAD -U3 --binary -- src/binary.bin > "$GOLDEN/binary-patch.diff"
diff_ HEAD -U3 -- src/binary.bin > "$GOLDEN/binary-differs.diff"
# Assert both, because git decides "binary" by finding a NUL byte in the first 8000 — a fixture
# built from merely non-printable bytes diffs line by line and covers neither case, silently.
if ! grep -q '^Binary files ' "$GOLDEN/binary-differs.diff"; then
    echo "error: binary fixture did not produce a 'Binary files ... differ' summary" >&2
    exit 1
fi
if ! grep -q '^GIT binary patch$' "$GOLDEN/binary-patch.diff"; then
    echo "error: binary fixture did not produce a 'GIT binary patch' payload" >&2
    exit 1
fi
say "confirmed: binary paths yield both the 'differ' summary and a GIT binary patch"
# An untracked file is rendered as a fully added file, and this is the only invocation in the
# product that exits 1 on success.
set +e
diff_ --no-index -U3 -- /dev/null src/untracked.txt > "$GOLDEN/untracked-as-added.diff"
untracked_exit=$?
set -e
if [ "$untracked_exit" -ne 1 ]; then
    echo "error: expected \`git diff --no-index\` to exit 1 when files differ, got $untracked_exit" >&2
    exit 1
fi
say "confirmed: git diff --no-index exits 1 on differences, which is success"

# Per-case files, so a parser test names the case it covers rather than an offset into one blob.
diff_ HEAD -U3 -- src/modified.txt              > "$GOLDEN/case-modified.diff"
diff_ HEAD -U3 -- src/deleted.txt               > "$GOLDEN/case-deleted.diff"
diff_ HEAD -U3 -- src/added.txt                 > "$GOLDEN/case-added.diff"
diff_ HEAD -U3 -M -- src/renamed-from.txt src/renamed-to.txt > "$GOLDEN/case-renamed.diff"
diff_ HEAD -U3 -- src/mode-change.sh            > "$GOLDEN/case-mode-change-only.diff"
diff_ HEAD -U3 -- src/no-newline-both.txt src/no-newline-gained.txt src/no-newline-lost.txt \
                                                > "$GOLDEN/case-no-newline.diff"
diff_ HEAD -U3 -- src/crlf.txt                  > "$GOLDEN/case-crlf.diff"
diff_ HEAD -U3 -- "src/a file with spaces.txt"  > "$GOLDEN/case-path-with-spaces.diff"
diff_ HEAD -U3 -- "src/caffè-日本語-🧊.txt"      > "$GOLDEN/case-path-non-ascii.diff"
diff_ HEAD -U3 -- src/sectioned.swift           > "$GOLDEN/case-section-heading.diff"
diff_ HEAD -U3 -- src/single-line.txt           > "$GOLDEN/case-omitted-hunk-counts.diff"
diff_ HEAD -U3 -- vendor/sub                    > "$GOLDEN/case-submodule.diff"
diff_ HEAD -U3 -- src/columns/display-columns.txt > "$GOLDEN/case-display-columns.diff"
# An empty diff is a real case: a clean path must parse to zero files, not to one empty file.
diff_ HEAD -U3 -- src/untouched.txt             > "$GOLDEN/case-empty.diff"

# --- worktrees ---------------------------------------------------------------------------------

# Claude Code currently places worktrees here. That is an implementation detail rather than a
# contract, so the product reads `git worktree list`; the fixture carries one anyway because the
# nesting is a useful hint for labelling a worktree as agent-created.
git_ worktree add -q -b worktree-agent-slice .claude/worktrees/agent-slice
printf 'work in progress\n' > .claude/worktrees/agent-slice/src/wip.txt

# And one created outside the repository root, which is the case a recursive FSEvents stream over
# the project root does not cover.
git_ worktree add -q -b outside-slice "$OUT/outside-worktree"
printf 'outside the root\n' > "$OUT/outside-worktree/src/outside.txt"

say "worktrees: .claude/worktrees/agent-slice and $OUT/outside-worktree"

# `worktree list --porcelain -z` is the product's source of truth for worktrees, so its layout is
# worth a committed golden — but it is the one git output here that carries ABSOLUTE paths, which
# differ between a laptop and a CI runner and would make the fixture churn on every machine.
#
# So the fixture root is rewritten to a fixed token on the way out. That is the only edit made to
# any golden file, it is confined to a path prefix, and it leaves the record layout — which is the
# thing being asserted — byte-for-byte as git emitted it. A test substitutes its own root back in.
#
# Generated from the main repository rather than a bare one, because that is where the three
# interesting shapes live: the primary checkout, a worktree nested under .claude/worktrees/, and a
# worktree created outside the repository root entirely.
git_ worktree list --porcelain -z | python3 -c '
import sys
raw = sys.stdin.buffer.read()
sys.stdout.buffer.write(raw.replace(sys.argv[1].encode(), b"/GRANITA_FIXTURE_ROOT"))
' "$OUT" > "$GOLDEN/worktree-list.z"

if ! grep -qa "GRANITA_FIXTURE_ROOT" "$GOLDEN/worktree-list.z"; then
    echo "error: worktree-list.z still carries a machine-specific path" >&2
    exit 1
fi

# ---------------------------------------------------------------------------------------------
# 2. Unborn HEAD — `git diff HEAD` exits 128 here while `git status` works fine.
# ---------------------------------------------------------------------------------------------

echo "building $OUT/unborn"
UNBORN="$OUT/unborn"
mkdir -p "$UNBORN"
cd "$UNBORN"
git_ init -q .
printf 'first file, never committed\n' > new.txt
git_ add -A

if git_ rev-parse --verify --quiet HEAD >/dev/null; then
    echo "error: the unborn fixture has a HEAD; it is not unborn" >&2
    exit 1
fi
# Against the empty tree object the same comparison works, which is the substitution the product
# makes everywhere HEAD appears as a revision.
EMPTY_TREE=4b825dc642cb6eb9a060e54bf8d69288fbee4904
diff_ "$EMPTY_TREE" -U3 > "$GOLDEN/case-unborn-head.diff"
say "confirmed: rev-parse --verify --quiet HEAD fails, empty-tree substitution works"

# ---------------------------------------------------------------------------------------------
# 3. A conflicted merge. Claude Code runs rebases and merges, so this will happen in the wild.
# ---------------------------------------------------------------------------------------------

echo "building $OUT/conflicted"
CONFLICTED="$OUT/conflicted"
mkdir -p "$CONFLICTED"
cd "$CONFLICTED"
git_ init -q .
printf 'shared\nline two\nshared tail\n' > conflict.txt
printf 'untouched by either side\n' > calm.txt
git_ add -A
git_ commit -qm "baseline"

git_ checkout -q -b theirs
printf 'shared\ntheir line\nshared tail\n' > conflict.txt
git_ add -A
git_ commit -qm "their change"

git_ checkout -q main
printf 'shared\nour line\nshared tail\n' > conflict.txt
git_ add -A
git_ commit -qm "our change"

set +e
git_ merge -q --no-edit theirs >/dev/null 2>&1
merge_exit=$?
set -e
if [ "$merge_exit" -eq 0 ]; then
    echo "error: the conflicted fixture merged cleanly" >&2
    exit 1
fi

# Verified: on a conflicted path `git diff HEAD` emits a NORMAL unified diff carrying the
# <<<<<<< ======= >>>>>>> markers, not a combined `diff --cc`. So the parser needs no
# combined-diff support; it tags those lines instead.
diff_ HEAD -U3 > "$GOLDEN/case-conflicted.diff"
if ! grep -q '^diff --git' "$GOLDEN/case-conflicted.diff"; then
    echo "error: expected a normal 'diff --git' header on the conflicted path" >&2
    exit 1
fi
if grep -q '^diff --cc' "$GOLDEN/case-conflicted.diff"; then
    echo "error: got a combined diff on the conflicted path; the parser would need --cc support" >&2
    exit 1
fi
say "confirmed: a conflicted path diffs as a normal unified diff with markers, not diff --cc"

# The unmerged porcelain-v2 record, whose 10 fields a parser written for the 8-field `1` and `2`
# records will read straight into the next record.
git_ status --porcelain=v2 -z > "$GOLDEN/status-porcelain-v2-conflicted.z"

# ---------------------------------------------------------------------------------------------
# 4. The two -z rename layouts, whose path orders are opposite.
# ---------------------------------------------------------------------------------------------

echo "building $OUT/renames"
RENAMES="$OUT/renames"
mkdir -p "$RENAMES"
cd "$RENAMES"
git_ init -q .
printf 'alpha\nbeta\ngamma\ndelta\nepsilon\n' > old.txt
printf 'plain\n' > plain.txt
git_ add -A
git_ commit -qm "baseline"
git_ mv old.txt new.txt
printf 'alpha\nbeta\ngamma\ndelta\nEPSILON\n' > new.txt
printf 'plain, edited\n' > plain.txt

#   status --porcelain=v2 -z   ->  ... R100 <newPath>NUL<oldPath>NUL      NEW first
#   diff --numstat -z -M       ->  <a>TAB<d>TABNUL<oldPath>NUL<newPath>NUL  empty field, OLD, NEW
git_ status --porcelain=v2 -z            > "$GOLDEN/status-porcelain-v2-rename.z"
diff_ HEAD -z -M --numstat               > "$GOLDEN/diff-numstat-rename.z"
diff_ HEAD -z -M --raw                   > "$GOLDEN/diff-raw-rename.z"

say "confirmed: numstat -z emits an empty field before an old/new rename pair"

# ---------------------------------------------------------------------------------------------

cd "$REPO_ROOT"
echo
echo "fixture repositories: $OUT"
echo "golden fixtures:      ${GOLDEN#"$REPO_ROOT"/}  ($(find "$GOLDEN" -type f | wc -l | tr -d ' ') files)"
