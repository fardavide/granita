# Batch native background validation and ASCII membership

Keep complete native Text, native widths and exact background geometry. Nominal glyph and advance
arrays are compared in batches, while string indices, finite values, zero origin and exact
positional continuity retain their existing checks. The validated native CGPoint array supplies
its original x coordinates directly; a separate mapped coordinate array is no longer allocated.
Unsupported runs and the terminal boundary retain native caret lookup.

Printable-ASCII eligibility uses Foundation character-set membership over the complement of
U+0020 through U+007E. Both source and highlighted text are still checked, with default search
options and the original attribute-container equality. Empty strings retain their prior result;
controls, DEL and non-ASCII scalars remain ineligible. The set is an immutable membership constant,
not a mutable layout cache. Segment eligibility remains unchanged: highlighting is accepted by
length, so rendered ASCII alone cannot establish that the original segments were ASCII.

The failing dense capture from [the third CI diagnostic](https://github.com/fardavide/granita/actions/runs/40831796653)
uses PID 18583 on Xcode 27.0. Its marked interval is 2485472708 through 4627492833 ns. The first
frame gap of one second contains 846 ms of sampled main-thread work after resolving timestamp
references. App, scene and key window remain active, UIKit animations remain enabled, and Reduce
Motion is false. Overlapping inclusive app costs in that gap include 432 ms in the line body,
338 ms in background preparation and 182 ms in glyph-position preparation. CoreText appears in
56 ms of those samples.
This identifies substantial Swift preparation work; it does not make the rest of the stall free.

Matched local dense recordings preserve the original assertions. Baseline sampled main-thread
work is 460 ms, with 165 ms in the line body, 128 ms preparing backgrounds and 77 ms preparing glyph
positions. Batched comparisons and native-point storage give 433/140/108/55 ms. Adding native
membership search gives 417/112/76/49 ms; eligibility itself falls from 49 ms to 10 ms. These are local
profiled comparisons, not a remote CI verdict or a bound on unprofiled runtime.

Rejected controls remain out of production. A 95-character nominal-font table changes glyph work
from 77 ms to 76 ms. Sparse exact native carets increase background work to 235 ms and total main work
to 533 ms. Direct byte comparisons do not improve eligibility. Bulk index validation plus carried
positions increases glyph work to 78 ms. Neither font averaging nor sparse glyph-origin assumptions
is introduced.

The 45 geometry and eligibility cases pass, as do both profiled behaviors, all 66 original
unprofiled interaction executions and all 56 reader snapshots. The complete package suite,
both unsigned Debug apps and generated-file verification pass. Fresh unsigned Mac and device
Release builds return zero with the existing exit-code-zero SwiftCompile diagnostic.

Fresh Unit, both iOS groups (1,169 executions) and Ui (22 executions) receipts share source digest
`eb848a572da095638cf56d6f1fe6844f70e2f8df4dbd09f806736ba2c4018225`.
The local Mac run records image mismatches and is interrupted at the user's request after its
windows repeatedly take focus. There is no successful Mac receipt or aggregate coverage verdict.
The required remote checks remain pending. No original assertion, physical travel bound,
animation timing, snapshot baseline or coverage scope changes.
