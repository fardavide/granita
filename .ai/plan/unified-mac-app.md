# Unified Mac app

Implements [issue 97](https://github.com/fardavide/granita/issues/97) and [issue 91](https://github.com/fardavide/granita/issues/91) from `design-mac.md` section 8. The design return and shared `WorktreeReader` landed in [PR 109](https://github.com/fardavide/granita/pull/109).

## Source and storage

- [x] Model This Mac separately from remote Bonjour sources; omit the advertised local instance from discovery.
- [x] Local reads use `LocalGranitaRepository`; local reviews use the server document directly, without a second defaults copy.
- [x] Remote reads retain pairing, wake/reconnect, pinned transport, and offline review reconciliation; Mac pairing uses six words. Native acceptance remains below.
- [x] Remember the last source and worktree; switching source cancels the previous reads.

Acceptance: focused tests assert source filtering/routing, review writes and reconciliation, and source/worktree restoration.

## Reader and application lifecycle

- [x] One Mac product named Granita, retaining `dev.fardavide.granita.mac`; mobile destinations return to iOS/iPadOS.
- [ ] Reader window: suppressed launch, default 1260×800, minimum 640×480, source popup, persistent worktree sidebar, trailing inspector for files/review.
- [x] Show Worktrees and Dock reopen bring the one reader forward; closing it keeps serving.
- [ ] View commands change code size, colours, side-by-side, inspector visibility and refresh.
- [ ] Local empty/blocked/gone states have the designed copy and working controls; existing Settings panes remain.

Acceptance: Mac UI tests press controls and assert effects, including server survival after close; phone snapshots preserve existing behavior.

## Verification and delivery

- [ ] Add Mac reader snapshots for seventeen designed states in light/dark and adopt runner baselines.
- [ ] Run sanctioned package, build, generated-file, snapshot, UI and coverage checks; report exact limitations.
- [ ] Update decisions, status, version and changelog; show exact PR text before publication.
- [ ] Once completed and verified, close issues as authorized and replace only verified installed Granita bundles, preserving data and identity.

The user explicitly approved tests that interact with the desktop. Use the sanctioned automated UI tests; do not enable desktop-control access.

**That approval was withdrawn on 1 October while Davide uses the Mac.** Do not run Mac UI tests,
app-hosted Mac snapshots or launch the app until desktop interaction is authorized again. Continue
headless checks and use CI for Mac snapshot rendering. Opening a PR is authorized when the
implementation is complete; remaining native acceptance must be stated precisely in its body.

Davide subsequently authorized installing and running the completed app. That permits the final
launch after verification; it does not resume Mac UI tests or desktop control. Replace only verified
Granita bundles, keep their data and identity, and use the minor release 0.22.0 already committed.

## Implementation checkpoint — 1 October 2026

The foundation and unified product are implemented on `codex/unified-mac-app`; final acceptance and release remain open.

- Typed source/worktree selection and UserDefaults restoration pass their focused tests, including switching sources, retaining the current source's selection, replacing saved values and rejecting malformed records.
- Discovery excludes the local Bonjour instance; the menu's domain projection retains remembered remote Macs through every discovery state. The connection model exposes their names without reading credentials.
- The local review adapter writes through the repository and reconciles from its authoritative review, with no second durable defaults copy. Viewer reconciliation now waits for queued writes and preserves edits made while a read is suspended.
- The application delegate is attached to the app shell. It keeps the process alive after the last window closes and publishes explicit Dock reopen requests.
- Mac pairing has a camera-free implementation of the existing capability seams; the phone assembly is unchanged.
- `make test` passed after `make fixtures` created this checkout's disposable fixture repositories; `make build` passed for the package, Mac server, iOS app and existing Mac client. These are foundation checks, not proof of a unified app.
- The authentication failure cleared after the user's “Try now”. Native UI tests subsequently passed Show Worktrees/local Projects recovery, reader-close/server-survival, and persistent worktree selection/reopen. Test fixtures use a temporary store and port zero, leaving the installed app's store unchanged.
- A local viewer loads authoritative review comments as part of its first diff read through `loadReviewsAtStart: true`. The default preserves the phone's loading behavior. The missing-argument RED was observed and all 47 comment tests passed after the minimal implementation.
- The reader model's local-access policy permits starting/running/failed/stopped hosts and refuses another process holding the store. Missing-method RED was observed; all five model tests, including the parameterized policy across every server state, passed. The unified screen binds that policy.
- The complete `make test` suite and `make build` passed again on 0.22.0. The build checks the package, unified Mac product and iOS app. `make coverage-tests` passes 102 collector/gate arithmetic tests.
- `make resolve` passed and restored the 30-pin Xcode union after package tests rewrote it; only the manifest origin hash changed, with no dependency pin updates.
- The product is Granita with the existing server bundle identifier. The unlocked native startup test exposed a real lifecycle regression: the invisible opener never ran its launch callback in the regular app. Anchoring SettingsOpener in the status label repaired it. The complete native suite passes eight tests, including remote words pairing and visible code-size changes; separate actual Dock-click and code-colour effect tests also pass. The live content-minimum test passes after allowing SwiftUI to apply its scene constraints. Native screenshots expose duplicate title chrome and a missing project/source subtitle; that fidelity fix and the remaining View actions are being verified.
- The installed server was verified at `/Applications/Granita Server.app`, stopped with SIGTERM and then SIGKILL because its process survived TERM. No installed bundles or data have been removed. Restore serving with the final app when verification is complete, or explicitly report its stopped state if blocked.
- Source-menu recovery states have typed tests and six light/dark snapshot subjects; eight reader subjects render the real inspector. The local Mac run fails expected runner comparisons and writes the 28 missing references; those images were moved to `.build/mac-reader-renders` for inspection and must not be adopted as CI baselines. Phone/iPad snapshots pass: 66 parameterized tests in 30 suites. Runner baselines, current UI acceptance, coverage, generated checks and release docs remain required.
- The latest complete native run passed twelve of sixteen tests. Refresh exposed a real product
  defect, now covered by seventy green viewer tests and fixed for unchanged visible file identities.
  Copy Review exported the correct document for the text the test had entered; the test lost one
  character while typing and now checks the composer before Save. Copy Logs passes its focused
  effect test within the actual waking resolver's retry budget. The header test now asserts native
  title/subtitle children directly, and fixture preferences are isolated. The final Refresh,
  composer/export, header and Show Worktrees reruns were stopped on Davide's request.
- Quiet-worktree selection now uses the complete inventory; focused tests cover selected quiet
  worktrees hidden from both mixed and all-quiet sidebars. Four launch-preference cases also pass.
- No issue has been closed, no PR text posted and no installed app replaced. Final native acceptance
  and installation remain deferred while the desktop is in use; a reviewable PR does not close them.
- Source choice now routes through the connection model; the three typed routing cases pass with
  the complete 65-test connection suite after a missing-method RED. The final package collector
  passes 1,899 tests in 180 suites across 36 bundles, and the package/Mac/iOS build passes.
- The latest full iOS comparison has one dark-phone gone-worktree mismatch confined to the last
  file's layout. The sixteen-case split-screen suite passes unchanged on an isolated run. Xcode
  then stalled collecting diagnostics after the failed full run; its owned process was terminated,
  leaving that collector incomplete. The complete CI comparison remains required.
- Thirty-four new Mac references are explicit temporary mismatch placeholders for the CI adoption
  round trip in decision 0078. Twenty-eight are earlier local inspection renders; six reuse the
  no-projects render for states added after desktop testing stopped. None is a final baseline, and
  all must be replaced or verified byte-for-byte against the runner before the PR opens.
- The first branch CI run passes package tests, both app builds and generated files. Its Mac
  comparison produces 66 mismatches: the 34 new references, twenty General renders carrying the
  changed Startup footnote, and twelve status-menu renders carrying Show Worktrees. The existing
  Settings and menu changes and the source-menu renders have been reviewed; the reader references
  remain temporary until its rendering defects are corrected and reviewed again.
- The runner's live window test observes a 640×532 content minimum. The split view adds its 52pt
  toolbar to the root's minimum, so the root now reserves 428pt below that toolbar for the designed
  640×480 window. The corrected geometry remains subject to the next CI run.
- Reader captures expose semantic-colour mismatches, an intrinsically sized blocked state, a
  vertically centred source above the empty sidebar, and an appearance task replacing the prepared
  47-second read. The snapshot host now pins the app appearance and full root proposal, then prepares
  fixtures after their appearance tasks start. The blocked detail and empty sidebar fill their
  column. These fixes build; the next runner capture must verify them before baselines are final.
- The second CI run passes the exact 640×480 window assertion and all existing Mac snapshots,
  including the twelve source-menu captures. Its twenty-two reader captures now have the correct
  blocked and empty-column geometry and the 47-second reading state, but some semantic foregrounds
  remain wrong. They are not adopted. The reader-only host now pins SwiftUI's colour scheme, drains
  the fixture transaction and captures under the view's effective drawing appearance. CI must
  verify that correction. Local UI tests remain stopped.
- Both iOS shards and the pinned TLS connection tests pass in the second CI run. Coverage refuses
  aggregation while the Mac snapshot suite is red, as required. Per-file unit exports identify
  rendered menu controls and the pairing composition in the host-only row: commands now wire a
  stateless Ui menu from the application root, and the pairing composition uses the existing
  Screen convention. Neither coverage predicate is changed. CI-only captures cover menu size
  bounds, inspector availability, pairing entry/refusal states and source composition; their
  twenty-two references are explicit placeholders until runner renders are reviewed and adopted.
- The third CI capture confirms legible menu, source composition and words-entry/refusal surfaces.
  Eighteen renders are reviewed and adopted; the unknown-word fixture now settles the misspelling
  before checking it. The spent-code refusal exposed phone-specific recovery copy on the Mac;
  Mac outcomes now name this Mac's device record and the remote Mac's Devices pane. Further
  captures cover every remote words outcome, including an unresolved address, failed token storage
  and pending spend/write. Reader sidebar/inspector colours remain unreadable in the bitmap path.
  A temporary CI-only experiment compares AppKit's compatible bitmap and controller hosting.
  No desktop access or machine setting is changed.
- Apple's `SCShareableContent.currentProcess` is documented in the installed SDK to enumerate
  content available to this process without TCC consent. The runner experiment also requires the
  exact fixture window identifier and owning PID before capturing its composed content. It never
  requests screen-recording permission or falls back to the display or another process's window.
- The fourth runner comparison passes package tests, generated files and both app builds. Its
  28 remaining pairing renders have been reviewed and adopted: the settled misspelling is visible,
  recovery names this Mac and the remote Devices pane, and pending spend/write stay distinct.
  Compatible AppKit bitmaps and controller hosting still lose the reader's semantic foregrounds;
  neither experiment is adopted. The fifth run checks only the fixture window's native composition.
- The fifth runner experiment preserves the selected sidebar row, dark inspector text and native
  control colours through the fixture window's WindowServer composition. The bitmap variants still
  lose those foregrounds. The reader capture now uses that exact owned window, scales the output to
  the existing two-pixels-per-point size, excludes the cursor, child windows and shadows, and asserts
  the raster dimensions. Its temporary probe and references are removed. A sidebar-load transaction
  is drained before setting the chosen inspector state. The sixth comparison must review all renders
  and prove stable fixture state before any reader baseline is adopted.
- The sixth runner capture preserves the complete reader in both appearances: selected rows and
  Files remain legible, Review shows both comments and Copy review, the 47-second read remains
  pending, and blocked/empty/gone states keep the designed column geometry. All 78 changed renders
  are reviewed and adopted; the two unchanged light pairing outcomes already match. The implemented
  design frames are removed. Package tests, both app builds and generated files pass on this revision.
  The ready PR's CI will judge the final baseline comparison and all six coverage ratchets. Native
  reruns remain paused at Davide's request; the issues stay open for those acceptance checks.
- Ready [PR #121](https://github.com/fardavide/granita/pull/121) is open with the 0.22.0 minor bump.
  `make run-mac` builds and launches the signed app. Its installed copy at `/Applications/Granita.app`
  validates with `codesign --verify --deep --strict`, owns the only normal Granita process and listens
  on port 8737; `/v1/health` reports serverVersion 0.22.0. The build-directory process ignored TERM
  and was stopped by its verified PID before the installed copy restarted. The old 0.20.0 Server
  bundle is removed after the new signature validates. JSON, Keychain and user preferences remain;
  only the ownership-verified code-control-fixture selection identifier and name are cleared.
  No UI tests or desktop-control access resume. Final PR comparisons and coverage are reported on
  the PR. The first committed-baseline comparison passes all 29 Mac tests in 17 suites.
- The complete [PR run](https://github.com/fardavide/granita/actions/runs/36919405056) passes
  every package/build/generated/snapshot check, including both iOS shards and pinned TLS. Unit
  coverage is 11930/12232 lines and 4580/4814 regions; All is 12004/12238 and 4610/4818. Snapshot
  is 13104/13251 lines and 2189/2249 regions, below main's unchanged ratchets. The per-file export
  locates unrendered remote Review settings, Mac viewer and source-composition states. Added
  fixtures cover empty and clean-worktree Review, failed/removed change sets, refused batches,
  new/editing comment sheets, remote reading while the local host is blocked, six remote Review
  settings states, remembered source selection, the actual pairing sheet, and three log-copy
  feedback states. The capture helper requires the fixture's attached sheet and its exact owning
  process/window identity when a subject presents one. Thirty-eight copied baseline placeholders
  will be replaced only by visually reviewed CI renders; the existing source fixtures are renamed
  for their now-parameterised test signature. Production code and coverage predicates are unchanged.
- Davide reports a phone-side timeout followed by cancelled reads, then confirms the iPhone works.
  Localhost health still reports 0.22.0; the Mac's self-tailnet health request times out, so that
  test does not establish why the phone's earlier request failed. No network, identity or machine
  setting is changed, no UI test resumes, and the installed app stays running.
- The next [CI capture](https://github.com/fardavide/granita/actions/runs/36932680094) supplies
  31 reviewed references for the new subjects. The six actual sheet captures expose an incorrect
  crop in the test helper; they are rejected and remain placeholders while the helper captures
  the entire owned sheet window. One light log-copy reference matched its temporary baseline
  within tolerance and is reseeded for a visible capture. The remembered-source assertion also
  identifies a fixture name mismatch: Bonjour's instance and display name must agree. Both fixture
  corrections await CI; production code and comparison tolerances stay unchanged.
- The [corrected capture](https://github.com/fardavide/granita/actions/runs/36935457096) passes
  the fixture assertions and the 31 previously reviewed comparisons. Only the seven remaining
  temporary references differ. Their full comment, editing, pairing and log-copy surfaces are
  visually reviewed and adopted byte-for-byte from the runner. All 38 new references are now
  reviewed; the final comparison and all coverage ratchets await the next complete PR run.
- The [complete comparison](https://github.com/fardavide/granita/actions/runs/36937505758)
  passes all builds, generated files, package tests, both iOS shards, pinned TLS, and all 30 Mac
  tests in 18 suites. Unit and All coverage and Snapshot lines pass. Snapshot regions are
  2201/2249 (97.865718%), below main's 2073/2117 (97.921587%) under the unchanged gate. The fresh
  export identifies the unrendered Mac refresh indicator. One new light/dark subject retains
  five ready entries while an automatic change-set read is parked, requires the spinner state,
  and cancels/awaits that read after capture. The owned window is captured in full so its native
  toolbar can be reviewed. Two opposite-appearance temporary references ensure CI supplies actual
  renders; all 38 preceding references remain unchanged. Production code and gates are unchanged.
