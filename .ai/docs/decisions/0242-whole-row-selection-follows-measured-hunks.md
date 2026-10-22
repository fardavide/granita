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

The current main [CI run](https://github.com/fardavide/granita/actions/runs/39224803139) passed that
specific test but failed other motion cases and a Mac composer assertion. The cause of the local
file-selection failure remains unverified. The coverage command stops before Mac collection and
aggregation, so there is no complete local coverage verdict. No expectations, baselines, tolerances
or coverage predicates were weakened.

Fresh Xcode resolution advanced the test-only SnapshotTesting pin from 1.19.6 to 1.19.7 and its
IssueReporting dependency from 2.1.1 to 2.1.2. The required `make resolve` output retains the complete
30-pin union; the lockfile was not hand-edited. These resolver changes remain visible in the diff
for approval alongside the incomplete local coverage verdict.
