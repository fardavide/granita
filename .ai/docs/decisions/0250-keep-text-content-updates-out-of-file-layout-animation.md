# Keep text content updates out of file layout animation

The file owns collapse and scrolling motion. Its native text keeps complete source, syntax
colours, changed backgrounds and its original position, while geometry-driven content updates
use the identity content transition. This changes neither the ancestor layout animation nor
insertion and removal opacity transitions. Apple's [content-transition contract](https://developer.apple.com/documentation/swiftui/contenttransition/identity)
distinguishes these operations.

[CI 386](https://github.com/fardavide/granita/actions/runs/40643806135), at `71c50ff`, passes both
app builds, generated files, package tests, Mac snapshots and iOS group 0, including native
input coverage. Group 1 has four failed collapse cases: viewed plain and word-diff successor
motion, a long successor and a dense successor. Coverage stops at that prerequisite and
produces no numeric verdict.

The approved visible-text-window experiment establishes a more specific rendering cause.
A native substring positioned at its measured origin reduces glyph copying but fails the
original translated-pixel check in both unified and split layouts. Native leading padding
produces the same differences. Replacing the offscreen prefix with blank characters restores
the original character positions and passes both translation and exact restoration checks.
That variant still spends 1,623 ms of sampled main-thread CPU in the dense collapse interval,
including 790 ms in transparency-layer composition, and fails the original arrival check.

Keeping that variant and changing only the text content transition to identity passes the
same dense acceptance behavior. Sampled main-thread work falls to 609 ms; the large composition
cost disappears. Returning the complete attributed string with the same content transition
also passes, at 626 ms. Windowing supplies little additional benefit and is removed completely,
including its helper, blank-prefix construction and experimental tests.

The minimized candidate adds the identity content transition to the two original native text
return branches. Its synchronized recording passes the unchanged dense behavior and contains
452 ms of sampled main-thread CPU, 60 ms of glyph copying and no samples in the previous
transparency-layer endpoint. The earlier full-text control contained 996 ms of main-thread work
and 316 ms of glyph copying. These are same-simulator diagnostic intervals, not a promise about
every device or the entire suite.

The minimized diagnostic source digest is
`f5184b63815e7c47b03a0e4bbd758476bf53e723efc36ebdc361a8a1cd260bea`.
Its exact app process is PID 20755 on simulator `51DB8430-7D81-4E88-A863-1F2B394D46FB`;
the recorded collapse interval is `[1045152541, 2258490583)` ns. Both phase markers and CPU
samples are present. The diagnostic wrapper and markers are removed before acceptance runs.

The first clean original suite passes 64 of 65 executions, including every collapse-motion and
translated-pixel case. The remaining later-file preparation case again observes its accepted
450 pt native movement being restored to the selected header. The later adjustment-policy
investigation and its focused controls are recorded in
[0251](0251-control-contextual-offset-adjustment-during-reading.md). Required remote checks remain
pending. Existing assertions, baselines, deadlines, curves and coverage gates are unchanged.

An additional selector regression test observes actual native animation during presentation
movement and compares the arrived header with an isolated rendering of the selected third file.
It passes the original behavior, rejects a known typed-initializer instant jump, and rejects an
animated landing on the middle file. These controls are removed. Frame counts and largest steps
remain diagnostic for this new selector test; no new smoothness budget is imposed on it. The
original 65 executions retain every assertion and the class now executes 66 cases.
