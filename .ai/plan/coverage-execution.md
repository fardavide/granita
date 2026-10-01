# Coverage execution optimization

Start: fetched `origin/main`, `10f42a20dcb903c37e3325106a5bde05da0b66e6`.

## Contract

Keep coverage.py predicates, scope names, baseline keys, all six ratchets, required check names,
test cases, snapshot layouts and pixel tolerances unchanged. The TLS integration verdict remains
required but its counters stay outside the historical measurement scope. No new optimization skill.

## Work

1. Establish the legacy measurement on the same source and toolchain. Retain that path for comparison.
2. Collect instrumented profiles and matching objects in each normal required suite. Keep verdicts
   and result bundles. Clear counters before warm executions; exclude counters from build caches.
3. Validate provenance, suite completeness and content hashes before profile-level aggregation.
   Coverage consumes artifacts without builds or tests. Local coverage uses the same collector.
4. Compare every category's covered/count values and verdict, cold and warm, including repeat runs.
5. Benchmark iOS sharding in isolated runners/processes with a complete suite inventory; retain
   per-process serialization. Adopt only after equal case inventory and coverage counts are proved.
6. Measure CI elapsed time, runner time, queues and transfers separately; get approval before PR
   publication and merging. Return reusable lessons for the global kickstart follow-up.

## Current CI evidence

Run: https://github.com/fardavide/granita/actions/runs/36673515912

- Coverage: 44m26s; measurement 40m51s; export upload 47s.
- iOS snapshot job: 21m21s; snapshot step 19m09s; test execution 726.173s.
- iOS inventory: 66 tests, 30 suites; TLS: 3 tests in a separate pass.
- macOS snapshot job: 3m31s; unit job: 3m36s.
- These are historical timings on application revision `10f42a2`; the same-source comparison below
  controls source revision and toolchain rather than assuming historical runs are interchangeable.

## Validation status

Verified locally on the unchanged application revision with Xcode 27.0 (27A266a), arm64:

- `make build` and `make test` passed. No app source, snapshot baselines, tolerance, coverage.py
  arithmetic, measurement scope or required ruleset name was changed.
- `make coverage-tests`: 102 passed; negative cases cover provenance, missing/corrupt mappings,
  incomplete receipts, failed argument cases, invalid enumeration and omitted shard methods.
- Full legacy measurement completed. Counts: unit lines 11647/11949, regions 4447/4681;
  snapshot lines 12759/12860, regions 2080/2124; all lines 11728/11955, regions 4482/4685.
- Unsharded iOS execution: 424.049 seconds. Shards: 234.101 and 231.639 seconds, each serialized
  in its own process. These are local test execution timings, not CI wall times.
- Exact legacy/shard inventory equality: 66 methods and 1100 argument records, all passed,
  no duplicates or omissions. The two mapping sets are byte-identical; exporting merged counters
  with one or both mapping sets produces byte-identical JSON. iOS snapshot covered counts,
  denominators and scope match the unsharded export exactly.
- Product archive/restore passed; the archive is 32 MB, preserves executable modes/symlinks and
  excludes counters. A source stamp taken before compilation rejects stale products at packaging
  and restoration.
- Required unit coverage matches the legacy covered counts, denominators and scope exactly.
- Final fresh-counter repeat passed: shard 0 ran 20 methods in 218.885 seconds; shard 1 ran
  46 methods in 226.584 seconds. Both artifacts and the unit artifact have the same source digest
  and Xcode/architecture identity. Their partition matches the full enumeration; the repeated
  iOS export still matches unsharded covered counts and denominators exactly.
- `make coverage-report` accepted unit and both iOS artifact identities, hashes and receipts,
  then failed because the failed Mac suite has no manifest. It emitted no passing report.
- Incidental SwiftPM lockfile churn was restored; only CI scripts, workflow, Makefile and this task
  record are changed. The branch and [PR #120](https://github.com/fardavide/granita/pull/120) were
  published with Davide's explicit authorization. No merge or global-skill update was made.
- `make coverage-mac` returned 65 with the documented local renderer mismatch (119 failed cases).
  No successful coverage artifact was emitted. The aggregate refuses absent/failed/stale inputs.

## CI equivalence and repeatability

Cold [comparison run](https://github.com/fardavide/granita/actions/runs/36762620517),
warm [run](https://github.com/fardavide/granita/actions/runs/36768430103), and both measurement paths
used commit `fb417db`, Xcode 27.0 (27A266a), arm64, the same runner image and unchanged application
source. Cold mode skipped compiled/dependency caches; the normal warm mode restored compatible
build outputs and cleared counters before execution. All suite verdicts passed.

The cold legacy and aggregate summaries are exactly equal, including scopes:

| Category | Lines covered/count | Regions covered/count |
|---|---|---|
| Unit | 11647/11949 | 4447/4681 |
| Snapshot | 12759/12860 | 2080/2124 |
| All | 11720/11955 | 4475/4685 |

Warm snapshot and total counts are identical. Warm unit coverage is 11650/11949 and 4448/4681.
Per-file export comparison isolated the entire difference to
`Client/Worktrees/Presentation/ClientWorktreesModel.swift`, lines 188–190: its cancellation-handler
closure ran zero times in the cold pass and once in the warm pass. The existing overlapping-read
test cancels the outer task after starting a replacement read; the first read may already have
finished by then. This is execution scheduling of an existing branch, not stale counters or a
mapping change. No baseline, scope, epsilon or test was changed. All six verdicts are identical.

The [PR run and repeat](https://github.com/fardavide/granita/actions/runs/36755883540) both passed
every required check, with exactly equal summaries. Their synthetic merge revision `5a0a98f`
includes [PR #119](https://github.com/fardavide/granita/pull/119), which merged into main during this
task. That independently reviewed view refactor explains the snapshot denominator of 12561/2117
instead of 12860/2124 on the branch. Comparing those different revisions would be invalid.
The first PR and warm branch result inventories also match the local legacy inventory exactly:
66 method identifiers plus all 1100 argument identifiers, each occurring once and passing.

## CI timing evidence

Elapsed time includes queueing and artifact transfer. Runner time is the sum of successful job
start-to-completion durations; it excludes queued time. Queue time below sums each job's wait
after its dependencies finish (initial jobs wait after run creation). These sums are parallel,
so they are not added to elapsed time. Transfer time sums upload/download steps, including
coverage exports, reusable test products and diagnostics; cache transfers are separate job costs.

| Run | Required-path elapsed | Total runner | Queue sum | Artifact transfer sum | Coverage job / measurement |
|---|---|---|---|---|---|
| Historical main, 36673515912 | 47m12s | 80m06s | 4m32s | 49s | 44m26s / 40m51s |
| PR first attempt, 36755883540 | 28m58s | 65m18s | 6m16s | 88s | 2m01s / 52s |
| Cold branch, 36762620517 | 34m33s | 74m56s | 6m44s | 87s | 2m12s / 55s |
| Warm branch, 36768430103 | 26m26s | 62m20s | 2m00s | 66s | 2m12s / 66s |
| PR repeat, 36755883540 attempt 2 | 22m30s | 51m36s | 8m07s | 62s | 2m18s / 67s |
| Final PR, 36776854512 | 27m05s | 51m19s | 7m06s | 64s | 2m02s / 55s |
| Final cold branch, 36776994777 | 30m28s | 56m51s | 21m01s | 64s | 2m08s / 55s |

The manual cold run also deliberately ran the retained legacy job: 40m40s runner time, 39m34s
measurement. Including this one-off validation job gives 40m50s full-run elapsed and 115m36s
runner time. It is excluded from the optimized required-path measurements, not hidden.

## Remaining iOS costs

The first PR's instrumented iOS execution took 502.065s and 618.408s on isolated runners versus
726.173s for the historical required unsharded pass. Snapshot steps took 951s and 1093s, leaving
roughly 7m18s and 7m40s outside xcresult's test interval. Logs show expensive simulator discovery
before Make's first recipe, followed by enumeration/launch costs. Build-product downloads took
1s/5s and restoration 9s/9s, so product transfer was not the dominant cost. TLS remained required
and took 191s, with only 16.314s in Xcode's test interval; rebuilding its separate scheme remains
a distinct cost. Exporting/reporting is now roughly one minute, without simulator work.

Local whole-suite weights balanced rendering into 234.101s and 231.639s (then repeated at
218.885s/226.584s), preserving all 66 methods and 1100 argument records. CI has additional runner
and startup variability, so those local timings are not presented as CI speedups. Rendering stays
serialized per process; two different runners/simulators provide isolation.

Follow-up commit `6e0a0c0` makes simulator selection lazy for non-iOS Make targets and passes the
already-selected CI simulator name into enumeration. Its integration test failed on the eager
lookup and passed after the change; all 102 tooling tests pass.

The [final PR run](https://github.com/fardavide/granita/actions/runs/36776854512) passed every required
check. Its summary equals both prior PR attempts exactly. The iOS shard jobs took 15m26s and
13m58s, versus 21m21s historically; their snapshot steps took 700s and 762s. The xcresult test
intervals were 411.369s and 550.294s, leaving 288.631s and 211.706s outside those intervals.
The latter's Swift Testing execution took 534.223s. Logs show the first Make recipe 12s into the
step, rather than nearly three minutes in the first PR run; Xcode startup/enumeration and rendering
remain real costs. Product restoration took 3s per runner; the required TLS step took 110s.

The [final cold comparison](https://github.com/fardavide/granita/actions/runs/36776994777) also passed
all suite verdicts. Its aggregate summary equals the initial cold summary; the retained legacy
measurement took 36m54s and its job 37m58s. Including that deliberate comparison gives 40m48s
full-run elapsed and 94m49s total runner time. The final cold run's 21m01s queue sum reflects
concurrent validation jobs competing for runners, not test execution.

Warm unit logs confirm an exact cache-key hit and 176.17s compilation, versus 348.53s in the
initial cold unit pass. Cached build outputs still need substantial compiler work on fresh runners;
a cache hit is not evidence of a skipped build. Counters are cleared before every pass and removed
before cache persistence. Rendering, build/cache, simulator discovery, test launch, TLS and export
costs are recorded separately rather than attributed to coverage arithmetic.

No app source, baseline, coverage scope, epsilon, required check name or test was changed in this
task. Local `make coverage` uses the same receipt validation, raw aggregation and verdict code;
the documented local Mac renderer failure still produces a failing verdict and no successful
artifact. Merging remains separately authorized and publishes through Xcode Cloud. General lessons
for global kickstart and its references are returned separately; no reusable policy was added here.
