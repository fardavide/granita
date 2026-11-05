# Recover the main coverage baseline after a cache miss

[CI 396](https://github.com/fardavide/granita/actions/runs/41875061095) reports all seven required
checks successful on `b0f6f6b`. Its application tests pass, including 582 native group-1 executions,
both original source-reopen variants and the delayed-header readiness control. No original
correctness assertion or deadline is relaxed.

The Coverage job restores no matching baseline cache. It continues without recovering the saved
main artifact, and the report marks every row new: no numeric comparison is enforced. The final
enforcement step exits zero with the skipped-gate message. A successful step therefore does not
establish the numeric validation required by [0243](0243-native-input-is-measured-by-behavioral-coverage.md).
The logs prove a cache miss; they do not establish why that cache entry is unavailable.

The existing local baseline helper retrieves the saved summary from main's last successful CI
run, [38164000536](https://github.com/fardavide/granita/actions/runs/38164000536), whose measured commit is `a6b56be`. Exact-count comparison with the current
CI summary finds unchanged Unit/All scope identifiers and four passing ratchets:

| Kind | Counter | Main baseline | Current CI |
|---|---|---:|---:|
| Unit | Lines | 97.5317% | 97.6095% |
| Unit | Regions | 95.1412% | 95.3008% |
| All | Lines | 98.0966% | 98.1381% |
| All | Regions | 95.7261% | 95.8510% |

These are comparisons of the saved exact counts, not a claim that CI enforced them. Snapshot's
approved scope change and Ui's first measurement remain deliberately unjudged; Unit/All must
continue to compare against main. No stored baseline value, scope, tolerance or predicate changes.

The local recovery candidate calls the existing retrieval helper after cache restoration on pull
requests. An existing baseline is retained; when none is present, the saved main artifact is
retrieved. Retrieval failure stops the job. The step receives the built-in token, with read-only
Actions permission added to the coverage job so it can read main's artifacts. Main pushes retain
their existing first-baseline bootstrap and cache-saving behavior.

A bounded workflow-snippet test follows the existing simulator-selection test approach. It executes
the actual recovery, report and enforcement commands in a temporary PR fixture, with an empty
cache and a fake GitHub CLI supplying the saved main summary. Lower same-scope Unit/All counters
must fail all four comparisons, while changed Snapshot and new Ui scopes stay unjudged. Before
the wiring repair, the enforcer incorrectly exits zero: one failed and 140 passed tooling tests.
After it, all 141 pass. Source review finds no blocker. The test does not simulate GitHub's YAML
condition engine, token injection, permissions or artifact service; those remain real-CI checks.

No application source or image baseline changes for this recovery. The next publication must
explicitly verify that Unit/All comparisons ran, as well as checking successful job statuses.
The previous single-commit/push approval is used. [PR #129](https://github.com/fardavide/granita/pull/129)
merged separately as `0caf8af` while this follow-up was being verified. Its tree matches the tested
`b0f6f6b` tree. This candidate now resides on `codex/coverage-baseline-recovery`, based on that main
commit, and needs a new PR. On 5 November, Davide approves the reviewed two commits, one push
and a new PR with the shown wording. Merge, certificate changes and release retries remain
outside that approval.
