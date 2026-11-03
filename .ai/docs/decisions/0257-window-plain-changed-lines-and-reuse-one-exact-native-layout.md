# Window plain changed lines and reuse one exact native layout

The validated text window introduced in [0254](0254-prepare-reader-values-before-layout-and-bound-native-text-ink.md)
originally required multiple word-diff segments. Plain additions and deletions still painted their
complete source. A local selector reproduction keeps the original three 160-row files, observation
and settlement deadlines, motion assertions, header alignment and exact header-image comparison,
while expanding each repeated ASCII line to 28,710 characters. It observes no animated movement
across a 1.55s callback gap. A complete app-only recording identifies native glyph painting as the
dominant sampled cost for this local fixture, not as a proven cause of remote word-diff failures.

Eligible addition/deletion lines now use the same validated window whether their parser supplied
multiple segments, one segment or none. Supplied segment text still passes the existing eligibility
checks. Full source continues to determine scrolling width and accessibility; unsupported text,
attributes, fonts or native mappings keep the original rendering. Prefix positions, terminal caret,
syntax colors and word backgrounds retain their existing native checks.

Windowing alone restores the expected header and exact image but still misses observed animation,
with a callback gap of about 0.8s. Each hunk therefore retains one immutable native layout, keyed
by full string equality and native font equality. A different text or font replaces that sole
entry through the original constructor and validation; highlighting eligibility is checked before
lookup. The private main-actor reference lives with the hunk, publishes no changes and compares
by identity in the equatable private line view. It does not retain a global or growing collection.
This narrowly supersedes 0254's statement that no layout cache is used.

The fixed uninstrumented local reproduction then passes: one execution, no failures, skips or
runtime warnings, two intermediate offsets, arrival at 0.396211s and header y116. Its exact image
comparison passes. A delivered callback gap remains about 250ms; uniformly smooth frames are not
established. All 66 original interaction executions also pass without changing their source.
The existing selector test then keeps its original 20-repetition input and adds the previously
failing 4,096-repetition input. Its three-line parameterization preserves all assertions and
deadlines, avoiding a duplicate test body. The resulting 67 interaction executions pass, with zero
failures, skips or structured runtime warnings, in
`/private/tmp/granita-collapse-window-cache-regression-20261103-a.xcresult`.

The unrelated larger word-diff overload remains a diagnostic failure and is archived rather than
redefined. Original full iOS verification, aggregate coverage and remote CI remain outstanding at
this decision's first recording. No baseline, assertion, deadline, physical motion bound, coverage
scope or ratchet is changed. A local result does not establish a CI repair or TestFlight delivery.

Subsequent full verification on Xcode 27.2 (`27B52`) and the iOS 27.0 simulator passes both
instrumented iOS groups: 589 plus 581 executions, no failures, skips or structured runtime warnings.
The complete package suite, both unsigned Debug apps, unsigned Mac and device Release builds,
resolver validation and generated-file checks also pass. Unit and both iOS receipts share source
digest `622fe58dae8196597b6d853ca454466079a77e7f40ff735b707a04569c97b6c8`.
The current local toolchain differs from the earlier CI toolchain. Aggregate coverage and remote
CI remain unverified, and the Mac desktop suite has no fresh local run.
The fresh Ui collector then passes all 22 executions: eight actual-touch cases and fourteen
native-input parameter runs, with no failures, skips or structured runtime warnings. Its receipt
shares the same source digest. The aggregate command validates Unit and both iOS inputs, then
stops at the missing Mac manifest before any numeric verdict; no prior Mac artifact is substituted.
