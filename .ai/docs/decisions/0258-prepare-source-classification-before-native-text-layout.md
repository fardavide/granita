# Prepare source classification before native text layout

[0257](0257-window-plain-changed-lines-and-reuse-one-exact-native-layout.md) did not repair
[CI 393](https://github.com/fardavide/granita/actions/runs/41696305308). Five original word-diff
cases exceed the unchanged 99pt motion bound, and the wide selector observes no animated movement.
Coverage stops at its failed iOS prerequisite, before a numerical comparison. The image comparisons
and Mac snapshots pass. No further publication or merge is approved by that failed run.

## Measured local controls

A fixed selector diagnostic doubles only the wide input to 8,192 repetitions, retaining the original
three 160-row files, settlement, motion, header alignment and exact image contracts. It fails observed
animation. A plain-string window then passes this fixed case: the renderer selects and validates its
visible text before constructing an attributed value for an unhighlighted, unsegmented changed line.
The attributed path shares the original native window checks and preserves supplied syntax colors.
An unsupported layout still returns the complete original value without copying its characters.

A separate fixed word diagnostic uses three explicitly opened files, each with 160 deletion/addition
pairs and 8,192 values per line. Its setup, 1.2s observation, arrival, 99pt step, header identity and
descendant-coherence contracts remain unchanged throughout the investigation. Plain-text copy
reductions alone still miss arrival. A resolved-font boundary trial also fails and is reverted.

An app-only native recording covers the complete marked word phase at
25.348743791–26.665702375s. Its 259 main-thread samples carry 1,334.675ms of inclusive sample weight,
including waiting and boundary weights rather than exact CPU duration. Overlapping costs include
950ms preparing text, 695ms preparing native glyph positions and 440ms in their validation loop.
The visible window accounts for 10ms. The trace is
`/private/tmp/granita-ci393-word-profile-20261103-a.trace`.

A package diagnostic times 32 distinct long word layouts, with fixture construction and independent
native correctness checks outside timing. Reading the same native buffers through scoped typed
pointers in a counted loop lowers total time from 478.383ms to 196.165ms. Every glyph, string index,
advance, finite-value, zero-origin and positional-continuity check remains. Pointer lifetimes stay
inside their buffer scopes; positive count and identically sized arrays prove each access. Written
constructor invariants justify the nonempty base-address unwraps. Independent review finds no
semantic or lifetime blocker. The word acceptance still fails arrival after this inner improvement;
its computed 157.667pt step also exceeds 99pt, although that later assertion is not reached.

## Source facts belong with immutable preparation

Prepared reader content now retains one character-classification flag per original line, derived
from both its raw source and every supplied segment. Only U+0020 through U+007E is printable ASCII;
empty strings and nil/empty segment lists retain their prior result. This font-independent fact
belongs beside the existing drawn lines and ruler projection in Domain. Initial reader batches
already prepare that immutable value away from the main actor. Raw core and wire values stay intact.

Unified rows reuse aligned flags instead of scanning every segment during native rendering.
Split rows have different indices, including their full-width rows, so they retain the complete
original checks after the existing line-kind guard. Actual accepted highlighting, foreground-only
attributes, font resolution, native mapping and every unsupported fallback remain in Ui. Full source
still determines scrolling widths and accessibility. No geometry, height, animation or design changes.

The focused missing-API RED becomes GREEN for 18 source/segment fixtures and the existing coherence
test. Native geometry and eligibility checks also pass. The unchanged word diagnostic then passes
all contracts: 43 samples, 33 intermediate offsets, first callback at 0.489472s, largest step
18.666667pt, arrival within 2pt at 1.121894s and exact final offset -62pt at 1.138573s. The successor
ends at y116 with 0.000764pt lag at viewport arrival. No skips or structured runtime warnings occur.
Its result is `/private/tmp/granita-ci393-word-prepared-ascii-20261103-a.xcresult`.

The fixed interaction-test source remains
`d08cc24aee74d58b28876c2258882354fc4c3576e27698d2aca18f1e4fee3a08`; its archived copy is
`/private/tmp/granita-ci393-word-preprofile-20261103.swift`. The temporary overloads and benchmark
are removed before original-suite verification. The justified pointer refactor passes focused checks;
its same benchmark measures 185.030ms. Original app-test source matches the published head exactly.

These are local controls, not a remote CI verdict or evidence of TestFlight delivery. Original-suite
regression, full build and coverage verification remain outstanding at this entry's first recording.
No assertion, deadline, snapshot baseline, coverage scope or ratchet is changed.

## Final local verification

After removing the temporary diagnostics, all 67 published interaction executions pass, with no
failures, skips or structured runtime warnings, in
`/private/tmp/granita-ci393-original-interactions-20261103-b.xcresult`. The complete package
collector passes every test bundle and produces its fresh receipt. Both unsigned Debug apps and
unsigned Mac/device Release builds pass through Make. Resolution retains the committed 30-pin
graph, and generated files remain in sync.

The fresh instrumented iOS groups pass 589 and 581 expanded executions, including the original
motion cases and both selector inputs. The Ui collector passes eight touch cases and fourteen
native-input executions. All results have zero skips and structured runtime warnings. Unit, both
iOS and Ui manifests are complete and share source digest
`59d00546a26cdb919ed75db975354ec27a504d1c4be1aa8322b939a55a580c70`.
Inputs live under `build/coverage-inputs/` in this checkout.

The standard aggregate command validates Unit and both iOS manifests, then stops with
`FileNotFoundError` for `build/coverage-inputs/mac/manifest.json` before producing a numerical
verdict. No old Mac artifact is substituted and no Mac desktop tests are run. Independent review
finds no actionable code issue. On 4 November Davide approves one additional commit and push,
`Prepare source facts and streamline native text validation`, from the reviewed `1a846f8` base.
Commit `9357704` uses that approval. [CI 394](https://github.com/fardavide/granita/actions/runs/41778328235)
completes with five of seven required checks passing. Both builds, package tests, generated files,
Mac snapshots and iOS group 0 pass. Group 1 passes 578 of 581 expanded executions: two manual
word-diff cases exceed the unchanged 99pt step bound at 111.33pt and 157pt, and the original short
selector observes no animated movement across a 416.61ms callback gap. The wide selector passes;
final header alignment and image comparisons pass. No skips or structured runtime warnings occur.
Coverage stops at its failed iOS prerequisite before producing a numerical verdict. The native
result is `/private/tmp/granita-ci394-ios1`.

The local improvements do not establish the common CI cause or a complete repair. A temporary
480-row short-line control passes locally and is not a reproduction. A current-source app-only
profile subsequently covers the complete original short-selector phase; both original selector
inputs pass. The short case still records a 183.34ms callback gap. Four file bodies, 313 text
bodies and two publications each of content width, viewport width and horizontal offset do not
show repeated geometry feedback. Preparation takes 4.39ms, full native layout misses 0.14ms and
window validation 15.27ms across the whole phase; synchronous categories overlap. Within a 140ms
interior interval, 27 main-thread samples carry 135ms inclusive weight, predominantly native
graph transaction flushing and lazy placement/traversal, with overlapping layer transaction work.
This is local attribution, not proof of the remote cause. The native profile is
`/private/tmp/granita-ci394935-selector-profile-20261104-c.trace`; its marked phase spans
0.885925166–1.252085041s. Every temporary hook and stress case is removed, restoring the exact
published source digest. A separate current-source CI diagnostic is prepared for review rather
than another renderer trial. Its full-group recorder is then exercised locally: all 581 expanded
executions across the original 64-function plan pass, recorder and collector exit zero, and the
marked selector phase fits inside the native recording. That case still passes with a 150.08ms
callback gap, with 3.26ms preparation and 11.53ms candidate validation. Native lazy placement and
graph updates remain prominent in sampled work; this remains local attribution. Temporary source
and coverage inputs are restored, and a fresh test build of the restored source succeeds. The
full diagnostic receipt and recording remain separate under `/private/tmp/granita-ci394-full-group-20261104-d`
and `/private/tmp/granita-ci394935-selector-profile-20261104-d.trace`. Further commits or pushes
require a new concrete review. TestFlight delivery
remains unverified; merge approval stays separate. The previously approved PR wording has not
been applied because its condition, all seven required checks passing, remains unmet.
