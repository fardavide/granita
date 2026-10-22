# Whole-row selection follows measured hunks

On 21 October 2026 Davide approved a prototype expanding taps and long presses from the gutter to
the whole code row, and adding long-press-and-drag alongside long-press-then-tap. The selection keeps
the existing indigo tint, rail and bottom-sheet composer.

The iOS input recognizer belongs to the file content and resolves touches through measured hunk
frames. This supersedes 0178's per-hunk iOS input without replacing its geometric constraint:
`floor(y / rowHeight)` is valid only after converting into the hunk that actually contains the touch.
Torn expander rows remain gaps, and a drag can enter another hunk in the same file without clamping
to the first hunk's last line. Comment endpoints remain typed line positions, never geometry.

A stock UIKit long-press recognizer integrates through SwiftUI's gesture-representable API. It
reports a stationary hold's position directly and allows ordinary native pans. The first SwiftUI
long-press/zero-distance-drag experiments prevented vertical scrolling and failed the actual-touch
hold test. Moving that sequence from the ancestor to the horizontal scroll did not repair it.
The native recognizer passed the stationary code hold and ordinary swipe tests.

Once a hold begins, native scrolling pauses until release or cancellation. Drag changes extend a
held range without opening a sheet; releasing a changed range opens the composer. Releasing a hold
without changing rows preserves the existing second-tap flow and lets the reader scroll before
choosing a distant endpoint. Cancellation restores scrolling and retains the current selection.

Split targeting uses the touched cell and retains its horizontal side throughout a drag. Empty
cells and dividers refuse targeting. Every targeting path observes the existing sheet gate.
The prototype does not add automatic scrolling at the viewport edge. Mac input remains per hunk.

The offline UI fixture exposes the selected endpoints to its out-of-process touch tests. The make
target accepts an optional single-test selector for the TDD loop; its default still runs the entire
required UI bundle. Diagnostic collection may be disabled locally after a failed run's automatic
simulator collector timed out after 600 seconds; test assertions and tolerances stay unchanged.

PR preparation ran the full coverage command. Package instrumentation and iOS shard 0 passed;
shard 1 passed all image comparisons but failed the existing later-file horizontal-scroll test
before its horizontal action. File selection moved the native vertical offset from -116pt to
-4948pt, so its subsequent 450pt move could not satisfy the existing two-screen setup requirement.
The focused interaction suite reproduced it. Removing the new inner handlers, scroll-disabling
modifier, native recognizer and hunk measurements in separate checks did not repair it; restoring
the original gutter-only view behavior also reproduced it. All experimental removals were restored,
except redundant inner-handler additions: the file-level recognizer owns iOS input, and the inner
view now retains its original behavior on both platforms.

The first [PR CI run](https://github.com/fardavide/granita/actions/runs/39721697056) reproduced that
setup failure and two collapse-motion failures. All six actual-touch tests, package tests, unsigned
app builds, generated files and Mac snapshots passed. Coverage stopped at the failed iOS suite.

An isolated checkout of the exact base, `ca4cbf56489bbaa8aa1f4a167a95852f9eaaa35f`, passed all 27
focused native cases on the same simulator. The failure image on the feature branch showed an empty
reader, and the native scroll remained attached throughout. Restoring the original file-content
view cleared the failure; retaining only its new state fields also passed. The new scrolling-pause
callback captured the containing reader implicitly. Capturing only the selection binding repaired
the jump with the full feature enabled: all 27 native cases passed. The failure path now attaches a
window image so a missing file cannot be mistaken for an offset-only discrepancy. No expectations,
baselines, tolerances or coverage predicates were weakened.

The repeated full coverage command passed package instrumentation and both iOS shards: 21 tests in
shard 0 and 57 in shard 1. It then stopped at Mac image comparisons (`coverage-mac` exit 65): 29 of
30 test functions failed on this macOS 27.0.1 host. There is still no aggregate local coverage
verdict. A fresh package test run, both unsigned app builds and all six actual-touch tests passed
with the callback fix. The [next CI run](https://github.com/fardavide/granita/actions/runs/39733012320)
passed all functional jobs, including both iOS shards and Mac snapshots. Coverage failed Unit
regions (94.9% against 95.1%), Snapshot lines (98.8% against 99.4%), Snapshot regions (96.5% against
97.9%) and All-tests regions (95.5% against 95.7%).

The export identified input decisions left inside the file view and missing refusal cases in
the draft, measured targeting and model. Transient finger state and measured-layout resolution
belong to Foundation-only domain values; the view forwards each action with a single call.
The native adapter's configuration and state dispatch have direct seams because SwiftUI exposes
no public initializer for its generic context or coordinate converter. Real-window hosting and
public hit testing did not expose the recognizer through UIKit's view tree, so direct adapter
tests complement the actual-touch suite rather than using private event injection. Coverage scopes,
baselines and tolerances remain unchanged.

Measured frames are read when input arrives, rather than while building the view. Reading them in
the body introduced a rendering dependency on geometry writes during collapse. Returning to
action-time reads cleared the four motion failures found by instrumentation: all 27 focused native
cases and both instrumented iOS shards (23 and 58 test functions) pass. The full package suite and
both unsigned app builds pass. The remaining uncovered input methods only bridge SwiftUI's opaque
context or construct the current targeting value; aggregate coverage still requires CI's Mac run.

Fresh Xcode resolution advanced the test-only SnapshotTesting pin from 1.19.6 to 1.19.7 and its
IssueReporting dependency from 2.1.1 to 2.1.2. The required `make resolve` output retains the complete
30-pin union; the lockfile was not hand-edited. These resolver changes were included in the approved
PR scope.
