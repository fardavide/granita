# Animation cadence is diagnostic

Davide asks to remove the animation test after repeated CI motion failures. The narrow change
removes three cadence assertions from the existing native interaction suite:

- Collapse no longer requires at least three intermediate viewport frames.
- Collapse no longer caps one observed step at a quarter of its total travel.
- File selection no longer requires observing movement while the native scroll-animation flag is active.

The measurements and attachments remain diagnostic. The selector test is renamed to describe its
remaining contract: reaching the requested header. Every original fixture still executes.

Final model/presentation offsets, the requested file's identity and reading state, native header
alignment and descendant geometry, arrival coherence, and exact selected-header images remain
asserted. Existing setup and completion deadlines remain; these still detect an operation that
does not finish. The app's animations, production source, snapshot baselines, coverage scopes and
numeric ratchets are unchanged.

This deliberately supersedes the earlier requirement to preserve all motion assertions in this
repair. It removes cadence from the CI contract; it does not establish that rendering stalls or
visible stutter are repaired. A transition with poor cadence can now pass these cases if its
remaining correctness checks pass.

The pending separate CPU-profile publication proposal is superseded. Local `make test`, `make build`
and `make resolve` pass; the lockfile retains all 30 pins without changes. All 67 iOS interaction
executions across 18 functions pass, with no skips or structured runtime warnings, in
`/private/tmp/granita-cadence-diagnostic-interactions-20261104-a.xcresult`. No production source or
generated project file changes. The existing 0.23.1 release notes are corrected to disclose the
remaining stutter. Remote CI and aggregate coverage remain unverified until the separately
approved publication completes. Previous conditional PR wording promising unchanged motion limits
or a complete animation repair is superseded and must not be applied. Davide approves one commit,
`Keep reader animation cadence diagnostic`, and one push. The newly reviewed replacement PR
wording may be applied only after all seven required checks pass. Merge approval remains separate.
