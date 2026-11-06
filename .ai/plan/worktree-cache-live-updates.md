# Worktree caching and live updates

Status: independently reviewed and implemented locally; full coverage blocked on Mac snapshots.

## Review dispositions

The independent review accepted the overall approach with five corrections, all adopted:

- Cache list summaries while retaining fresh content and viewed-mark validation.
- Reconcile each worktree's content identity before touching its viewer or sidebar.
- Scope response publication, cleanup, timers and failures to the owning reload generation.
- Remove periodic full change-set scans of quiet worktrees.
- Enforce the four-process limit around the shared Git client, across scans and reader requests.

## Agreed behavior

The Mac prepares worktree summaries in the background. Opening the list reads a warm,
in-memory snapshot instead of computing every worktree's change set during the request.
File and Git changes refresh the affected summaries and notify connected readers.

The isolation requirement is mandatory: while reviewing worktree A, changes to worktree B
must cause no visible refresh, loading indicator, navigation, rearrangement, or content change
in A's review surface, including a visible sidebar. B's background state can advance; its
presentation catches up when the reader returns to the list or explicitly requests a refresh.

Changes to A automatically reload A. Reuse the existing reload path initially. Skipping
unchanged content is worthwhile when straightforward; incremental rendering, preserving scroll
through changed content, and special handling while an agent is actively editing are deferred.
Do not wait for an agent-completion signal or infer completion from a quiet filesystem.

## Starting point

- `WorktreeRegistry.worktrees(inProject:)` enumerates projects and then describes their
  worktrees sequentially. Describing each row calls `WorktreeService.changeSet`.
- That change set resolves HEAD, reads status, raw changes, numstat and untracked paths, and
  hashes changed files. Caching enumeration alone leaves most of the current work in place.
- The [September profile](../docs/loading-profile-82.md) measured 5.843 seconds for five
  projects and ten worktrees, including 5.828 seconds in git and 0.054 seconds in enumeration.
  This is historical evidence; rerun the profiler before claiming a current speedup.
- HTTP and local readers already meet at `WorktreeReader`. Share the cache and update source
  beneath that boundary instead of introducing separate caches for the two readers.
- `ServerWatchData` is a placeholder. `HttpTransport.send` returns a complete response body;
  it cannot be used as-is to consume a connection that remains open for events.
- `ClientViewerModel.load` resets loaded entries, highlighting, images and collapsed state.
  That is acceptable for the initial same-worktree update path, subject to the isolation rule.

## Server snapshot and refresh ownership

Use one actor-owned cache/coordinator per server instance, keyed by `ProjectID` and
`WorktreeID`. Keep inventory and computed change metadata together, but keep user-owned
aliases, pins and viewed marks as current store overlays. A store write should not require
a git scan to update those overlays.

Each entry retains the last successful result, its actual scan time, refresh state and a
typed publication generation. Failed refreshes retain that result and its age; they must not
turn failure into a clean worktree, an empty inventory, or a newly successful scan.

Warm enabled projects at startup after acquiring the existing store ownership lock. A cold
request joins the ongoing initial scan. Warm requests use the prepared snapshot and schedule
needed revalidation without waiting for an unrelated worktree. Pull-to-refresh explicitly
awaits a new scan; it must not merely return the same cached answer.

Share in-flight work per key. Start with at most four concurrent git subprocesses globally,
with at most one change-set scan per worktree. A cancellation from one reader must not cancel
server-owned warming or work shared with another reader. Stop owned work when the server stops.

Track invalidations arriving during a scan. They leave another scan pending; completion must
not accidentally mark newer changes clean. Publish complete results atomically before emitting
an update. Do not attempt transactional filesystem snapshots across git subprocesses in this
slice; the next scan converges after concurrent edits settle.

Compare the published content and metadata before notifying readers. A shared git directory
may invalidate several worktrees, but unchanged worktrees must not receive content-change
notifications. The existing status-derived revision alone is insufficient: an already modified
file can change contents without changing its porcelain status. Include file content hashes,
membership, statistics and relevant branch/HEAD metadata in change detection. Treat store-only
summary changes separately so a viewed mark or alias does not trigger a diff reload loop.

Cached paths remain internal. Check current project visibility and directory validity at the
existing access boundaries; a cached row never authorizes reading a project that was disabled.
Evict removed projects/worktrees and discard late scans that would restore them. Keep cache
memory bounded by existing per-worktree size guards and the current enabled inventory.

Cache list summaries only. Keep fresh change-set validation for diff, line and image reads
and for marking content viewed; a cached hash cannot validate newly read working-copy bytes.
Reconnect compares the open worktree's own content identity before any UI mutation, regardless
of changes in other worktrees or a server restart. Reload ownership guards cover cleanup,
timers and failures as well as successful responses. The four-process ceiling wraps the shared
GitClient so cache scans and interactive reads obey the same limit.

## File and Git observation

Implement one FSEvents union watcher behind a Domain-owned observation protocol. Discover
the actual common and per-worktree git directories through the git boundary; do not assume
every checkout has a `.git` directory beneath its root.

- Watch enabled project roots, external linked worktree roots, common Git metadata, and each
  worktree's Git metadata. Rebuild watched paths when project visibility or inventory changes.
- Map ordinary file events to affected worktrees. Observe worktree registration, HEAD,
  index, refs/packed refs, merge/rebase metadata and ignore-rule changes as appropriate.
  Shared metadata can require checking multiple worktrees, followed by per-worktree comparison.
- Filter known generated directories before scheduling work, following SPEC section 8.
- Debounce bursts for 400 ms and start scans at most once every two seconds per worktree.
  Continuous events must still allow refreshes; a trailing debounce must not starve publication.
- Reconcile after wake, watcher restart, dropped/coalesced events requiring a rescan, or root
  disappearance. A failed scan does not prove a worktree was removed.
- Use event-triggered scans and wake/event-loss/explicit-refresh reconciliation. Do not rebuild
  every change set on a periodic timer. Any periodic inventory backstop enumerates membership
  only; it does not hash unchanged files. Observe relevant external ignore/configuration paths
  where discovery identifies them.

Application store writes must also invalidate inventory or publish summary updates through
the same owner. Add an observable store seam or a tested decorator around store mutations;
do not duplicate refresh policy in Settings, routes and composition roots. Session-derived
labels remain a separate cached input and never block a git refresh on transcript reading.

## Events and client lifecycle

Expose typed updates through a Domain-owned stream. HTTP maps it to the already specified
authenticated `/v1/events` SSE route; `LocalGranitaRepository` observes the same source directly.
Keep one remote subscription per connected source, shared by the list and viewer.

Distinguish inventory changes, summary-only changes and worktree content changes. Content
updates carry `WorktreeID` plus the published generation. Define shared wire values in
`CoreApiDomain`, preserving typed identifiers; never send a path. Add scan freshness to the
response contract without treating response arrival time as the time git was last checked.

For the first implementation, reconnect with bounded backoff and perform full reconciliation
instead of building durable event replay. Subscribe before reading current state, buffer or
coalesce intervening notifications, and compare generations to close the subscription/read gap.
Compare content identities across server restarts; an unrelated inventory change must not stand
in for a change to the selected worktree. Bound subscriber buffers; overflow must require
reconciliation rather than silently dropping the final update for a worktree.

SSE uses the existing bearer authentication, version policy, TLS pinning and redirect refusal.
Send a heartbeat every 20 seconds. Cancel subscriptions on source switches and backgrounding;
reconnect and reconcile on foreground. Recheck authorization for long-lived subscribers and
close them on device revocation. Add a streaming transport seam in Client Connection Data;
keep HTTP framing and FSEvents out of Domain and view code. Verify streaming APIs against the
pinned Hummingbird and installed Foundation versions before selecting concrete signatures.

Gate event support explicitly for mixed client/server versions. Existing one-shot reads and
manual refresh must keep working when the server does not support the new stream. Do not
retry an unsupported route forever or describe a disconnected stream as live.

## Client update routing

Filter by source identity and `WorktreeID` before changing any viewer loading or error state.
An update for B while A is open does not call A's reload, update its progress, or publish a
sidebar arrangement. Inventory events check whether A actually disappeared or became disabled;
adding/removing B alone does not disturb A. Returning to the list reads the latest snapshot.

For A's content changes, coalesce updates while a reload is running and schedule a final read
of the newest generation. Add a request-generation check so old change-set/diff/image responses
cannot overwrite newer content or a newly selected worktree. Reuse the existing reload path;
do not make incremental rendering a prerequisite. Summary-only updates do not reload the diff.

When the list itself is the active surface, apply background updates without entering global
loading state. Retain usable content on refresh failure. Keep explicit pull-to-refresh available.

## Module ownership

| Responsibility | Placement |
|---|---|
| Snapshot state, scheduling policy, per-worktree generations and observation ports | Server Worktrees Domain |
| FSEvents adapter | Server Watch Data |
| Git directory discovery | Server Git Domain command vocabulary and Server Git Data execution |
| Store observation contract/adapter | Server Store Domain / Data |
| Typed wire updates and freshness values | Core API Domain |
| SSE framing, authentication and response mapping | Server API Presentation |
| Client update capability and source lifecycle policy | Client Connection Domain |
| Pinned streaming transport and decoding | Client Connection Data |
| Local event adaptation | Server Reader Data |
| Worktree filtering and reload state | Existing client Domain/Presentation modules |
| Construction and lifetime wiring only | Existing app and CLI Main modules |

Add seams with handwritten test doubles where they are needed; add no external dependencies.

## Implementation order and verification

Each code slice begins with a failing behavioral test, then the minimum implementation and
refactoring under the repository's TDD workflow. Keep implementation commits separate from
this draft and from previously completed fixes.

1. Measure the current baseline and introduce cache/refresh ownership. Prove a warm unchanged
   list request launches zero git processes; simultaneous reads share scans; fresh requests
   advance freshness; failures retain prior results; disabled projects are immediately hidden.
2. Implement observation and invalidation. Exercise real file edits, staging, commits, branch
   switches, external linked worktree creation/removal, shared refs, ignore changes and wake/
   event-loss recovery. Prove events during scans are retained and continuous edits converge.
3. Add event publication and both adapters. Prove cache-before-event ordering, no event for an
   unchanged rescan, same-status/different-content detection, bounded slow-consumer recovery,
   authentication/revocation, cancellation and reconnect reconciliation.
4. Add client routing. The primary acceptance test opens A, repeatedly edits and commits in B,
   and asserts zero reads, loading-state changes or visible rearrangements in A and its sidebar.
   Also cover identical file paths in A/B, shared-Git invalidations, unrelated inventory events,
   source switching, A changing, A disappearing, and old responses arriving after a newer read.
5. Verify the end-to-end path on the local reader and remote phone reader, plus foreground and
   network reconnect. Measure warm latency and background git workload on the same inventory
   as the baseline; report scan duration separately from debounce and network delay.

Run the sanctioned `make test`, `make build`, `make resolve` and `make coverage` checks for
implementation. Add the watcher test target to the existing package collection. Run relevant
snapshot and simulator behavior checks for client wiring, with animations disabled for UI tests.
Host desktop interaction needs session-specific approval naming the app and interruption risk.
Record the actual commands and results below; focused component checks alone do not establish
the complete app path.

## Documentation and first-slice boundary

The implementation must record a decision and update architecture, status and design prose.
Automatic application replaces SPEC section 10's required "Changes available" pill and the
earlier foreground-only list policy where the live subscription now reconciles. Preserve the
history of those decisions. Any genuinely new reader-visible state follows design-handoff;
the initial implementation should reuse established surfaces and controls.

The first implementation includes server caching, observation, events and automatic scoped
client reloads. Persisted caches, diff-content caching, agent hooks/completion detection,
incremental diff merging, and preserving a reading position through edits remain outside it.

## Implementation checkpoint

- Independent review completed; its five dispositions above are adopted.
- Focused tests pass for warm-cache reads, explicit HTTP/local refresh, content-sensitive
  revisions, store observation, a shared Git process budget, bounded SSE framing, heartbeats
  and authorization, prepared reads with scan age, and client worktree/sidebar isolation.
- Real-file integration passes from native FSEvents through observation, cache publication and
  local updates to an HTTP prepared read. Successful deletion immediately evicts the cached row;
  scan fencing prevents an old scan from restoring it.
- Failed-project tests cover healthy publication beside retained results and suppression of
  incomplete inventories when a visible project's initial scan has never succeeded.
- Native FSEvents delivery and stopping pass against a real file. The fixture uses POSIX
  canonical paths because Foundation normalizes the `/private/var` spelling back to `/var`.
- The first full package sweep and unsigned package/Mac/iOS builds pass. The phone UI test proves
  own-worktree automatic reload and no viewer read, spinner or content change for another worktree.
  The iPad bundle `build/live-worktree-ipad-toolbar.xcresult` reports two passed tests, no failures
  or skips, and two fixture orientation warnings. The sidebar test preselects A in the production
  Mac split composition, verifies two live subscriptions and a real B revision advance, then
  checks unchanged A reads/content and sidebar/code frames with no progress indicator.
- The iPad fixture does not validate the mobile split's value-navigation row-tap route. That route
  did not open its detail in the fixture and remains unresolved and unchanged.
- External global Git configuration and excludes files outside discovered checkout/Git roots are
  not separately discovered or watched. Explicit refresh or wake reconciliation re-reads their
  effects; discovering those additional paths is a follow-up.
- Lifecycle tests cover lock refusal, owned preparation, wake reconciliation and awaited cleanup
  on normal completion, cancellation and failure. Both roots use the shared process budget.
- Independent implementation review found and drove fixes for late responses restoring deleted
  worktrees, discarded nested-worktree status changing parent revisions, and raw-line buffer
  overflow corrupting SSE framing before the retryable transport failure could be seen.
- Live authorization failures reach the existing Pair Again state and invalidate late reads and
  deferred snapshots. The focused sidebar/viewer suite passes all 172 tests after this correction.
- Final `make test` passes; unit coverage collection independently reports 2,089 passing tests and
  writes a complete artifact receipt. Final `make build` passes the package and both unsigned apps.
  Selected snapshot suites pass 29 tests over 116 parameterized runs with no failures, skips or
  runtime warnings. Baselines remain unchanged. Warm reads are proven to launch zero Git calls;
  no current real-inventory latency comparison or physical-device LAN validation is claimed.
- The feature is prepared as one reviewed local commit, with no push, host app installation or release. The package resolver's lockfile
  is regenerated through `make resolve`: all 30 dependency pins are unchanged; only the origin hash
  changes. The user approved proceeding with the full `make coverage` gate, including its Granita
  Mac desktop tests, after another independent code review. That review identified four additional
  correctness gaps, all reproduced with focused regressions and fixed: failed missing-root first
  inventory, first stale-summary visible reload, late viewed-write failure publication, and project
  visibility changing during inventory rendering. The reviewer confirmed the corrections; grouped
  registry/viewer tests pass. The first full gate exposed two legacy missing-folder list regressions.
  Legacy lists now omit unknown missing folders without seeding a complete cache; prepared/live
  inventories stay strict. Both adapters use a fresh uncached list fallback for that specific
  unavailable-project failure. Parameterized local/HTTP tests prove current rows after a warmed
  cache, and the reviewer approved this compatibility correction. The gate will be rerun after
  the phone/iPad UI test is made executable without skips on both devices.

### Latest full-gate run

The corrected sources pass all 2,094 reported package tests under coverage collection. Both iOS
snapshot shards pass all 1,171 runs (589 + 582), and behavioral UI collection passes all 25 runs,
including both live-update checks. These receipts report no failures, skips or runtime warnings.
The separate phone and iPad runs each pass both live-update tests without skips; iPad retains its
two fixture orientation warnings. Final unsigned package/Mac/iOS builds and `make resolve` pass;
all 30 dependency pins are unchanged.

The Mac step reports reference-image mismatches in unchanged Settings surfaces. An inspected
General serving-light pair has the same copy/layout with different glyph rasterization; no matched
main-control run was performed and no definitive rendering cause is claimed. The first
`MacReaderMenuViewSnapshotTests/menu(subject:appearance:)` case then stopped progressing. The
run was interrupted on 7 November; the owned host and xcodebuild processes were confirmed exited,
while the user's existing Granita 0.23.3 app in another checkout was left running. The failed bundle
is `build/coverage-inputs/mac/tests.xcresult`, including the canceled menu case. The command reports
`coverage-mac` Error 75 and `coverage` Interrupt 2. No numerical coverage verdict or CI pass is
claimed, and no baseline or tolerance was changed to bypass the Mac check. Full coverage remains
blocked on that Mac snapshot run. The feature is prepared as one reviewed local commit and remains
unpublished; the validation blocker stays recorded with it.
