# Rejected: apply the code fade to clipped rows

3 November 2026. Rejected after the remote comparison; the motion repair remains unresolved.

## Evidence

The [video diagnostic](https://github.com/fardavide/granita/actions/runs/41599192275)
fails the original viewed/word-diff motion check while 579 other executions pass. Independent
pixels show the successor header holding for 80ms while the outgoing header continues moving,
then jumping approximately 433pt between recorded frames. This establishes a visible hitch,
not which view or framework operation causes it.

The full-code horizontal scroll previously carried one fade mask over its entire height. The
candidate applies the same fade to each already-framed, clipped code row and keeps rectangular
clipping at the scroll boundary. The fade still occupies the trailing 26pt. Leading alignment
positions the mask container; it does not change which edge fades. Split-cell masks are unchanged.

Four local recordings alternate control, candidate, control, candidate on the same simulator,
original fixture, instrumentation and checks. Each executes the original 580 cases, including
76 line snapshots, with no failures and exact restoration of temporary instrumentation.

| Matching viewed/word-diff phase | Control A | Candidate A | Control B | Candidate B |
|---|---:|---:|---:|---:|
| Main-thread sample weight outside Mach waits | 255ms | 185ms | 225ms | 170ms |
| First callback after capture begins | 52.63ms | 41.93ms | 46.56ms | 39.94ms |
| Maximum subsequent callback gap | 33.36ms | 33.23ms | 33.22ms | 33.28ms |

Sample weights are not exact CPU durations, and inclusive framework costs overlap. Both local
versions pass the original physical motion bounds; this experiment does not reproduce the remote
failure or prove it repaired. The consistent work reduction warrants retaining the small local
candidate for further verification, without claiming an improvement in the longest callback gap.

Artifacts are `/private/tmp/granita-fade-word-{control,candidate}-20261103-{a,b}`. Each recording
contains source fingerprints, the native trace, test inventory and original result bundle.

## Decision

The initial local result warranted comparing the two modifier changes on the remote runner.
Width measurement, full source, native text, row geometry, scrolling, gestures, accessibility,
block placeholders and the separate overflow indicator keep their existing contracts. All
original assertions, deadlines, baselines and coverage gates remain unchanged.

A fresh source review found no actionable fidelity regression. The remote result below rejects
the candidate as the motion repair; its two modifier changes are removed from the repair workspace.
No further commit, push or CI run is authorized by this decision.

Fresh `make test` and `make build` pass for the retained local candidate and image-host repair.
`make resolve` regenerates the full 30-pin Xcode graph, leaving the lockfile unchanged. Diagnostic
tooling checks also pass. No Mac GUI tests run, and there is no fresh aggregate coverage verdict.

## Approved diagnostic comparison

Davide approved the three-file comparison proposal. Commit
`7f15f68709f579e3dff3526aa4f5a37441590304` is pushed to `codex/selector-ci-profile`, starting
[the candidate video diagnostic](https://github.com/fardavide/granita/actions/runs/41636763527).
The guard allows only the exact candidate file blob while preserving the original source controls
for every other app/package source, test, baseline and project setting. The job retains the same
original group and ten-second native video without CPU profiling.
[PR #129](https://github.com/fardavide/granita/pull/129) remains open and unchanged at `4324c953`.
This approval is used; another commit, push or run requires a new concrete approval.

## Remote result

The job fails after 20m26s. All 580 executions finish: 576 pass and four fail, across two test
functions. The original collapse bounds fail for viewed/wordDiff (210.67pt),
viewed/unsegmentedWordDiff (176pt), and manual/wordDiffSuccessor (119.33pt), each against 99pt.
File selection also reports no observed animated movement across its 5,878pt travel.
Image comparisons pass. The tooling checks pass all 143 cases; structured runtime warnings are
empty. The recorder succeeds, its native phase fits the active capture window, and temporary
source fingerprints match exactly after restoration. Six critical downloaded hashes match the
producer manifest. Artifacts are `/private/tmp/granita-ci-video41636763527`.

The native movie confirms a visible discontinuity. The Next.swift gold marker remains at
y2478–2531 at movie times 1.158333, 1.228333 and 1.260000 while the translucent First.swift marker
moves from y376–447 to y1016–1086. At 1.290000 the Next.swift marker is at y422–493, approximately
685.3pt upward across 30ms at 3× scale. Recorded frames change during the hold, so this is not
only a gap in the main-thread observer or a globally frozen video. Movie timestamps do not
establish exact display-refresh timing or identify the responsible layout operation.

The candidate reduced sampled local work but did not repair the remote motion. It is discarded
from the repair workspace, verified byte-for-byte against its existing product source. The
diagnostic branch retains the approved failed experiment as evidence; it receives no further push.
