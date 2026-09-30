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
- Prior timings are historical; no optimized CI benchmark exists yet.

## Validation status

Verified locally on the unchanged application revision with Xcode 27.0 (27A266a), arm64:

- `make build` and `make test` passed. No app source, snapshot baselines, tolerance, coverage.py
  arithmetic, measurement scope or required ruleset name was changed.
- `make coverage-tests`: 101 passed; negative cases cover provenance, missing/corrupt mappings,
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
  record are changed. No PR, merge or global-skill update was published.
- `make coverage-mac` returned 65 with the documented local renderer mismatch (119 failed cases).
  No successful coverage artifact was emitted. The aggregate refuses absent/failed/stale inputs.

Still required: full CI legacy/new comparison on one revision/toolchain, cold and warm runs,
repeatability, per-file investigation of any drift, and measured CI runner/queue/transfer totals.
Latest historical CI elapsed time was 47m12s; summed runner time was 80m06s. No optimized CI timing
is claimed yet. Davide approved pushing the branch for mobile review; PR publication and merging
retain separate approval boundaries.
