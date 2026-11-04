# Measure visible word backgrounds before native text

Dense word changes can delay collapse while the viewport waits for newly visible rows. A
synchronized simulator CPU trace identified native rectangle painting during the pause. Removing
only word backgrounds eliminated it, but changed the screen and was not a repair.

The reader keeps its original native `Text`, complete characters, foreground attributes and
native width ruler. Before preparing word-background attributes, the UI measures the complete
effective string with CoreText and the actual resolved SwiftUI font. It retains whole changed
spans whose measured horizontal extent can reach the viewport, including the font's conservative
glyph overhang. It does not trim source text or place glyphs itself.

This path applies only to printable ASCII with foreground-only highlighting and a font that maps
the printable repertoire. Character offsets then equal CoreText's UTF-16 indices. Unsupported
text, attributes or native geometry retain the original backgrounds. The invisible ruler has a
text-only projection, avoiding unused changed-range preparation while preserving tab semantics.

Native endpoint queries must be batched. An initial implementation correctly assigned only 240 of
27,648 backgrounds, but still queried every span: the endpoint interval consumed 575 ms of 688 ms
preparation. Two searches over the ordered changed ranges locate the potentially visible spans;
only those few spans receive the final conservative intersection check. The searches use native
positions, not estimated character widths. Viewport and effective font inputs participate in
view equality; there is no retained layout cache or prebuilt view tree.

Printable-byte checks use scoped contiguous UTF-8 buffers. This preserves the eligibility
predicate while avoiding generic string-view iteration.

The runner's remaining preparation cost is native caret measurement. In
[CI 384](https://github.com/fardavide/granita/actions/runs/40468956878), the profiled dense replay's
first callback gap is approximately 633 ms, with 620 ms of sampled main-thread running time.
Native endpoint queries account for 284 ms inside that interval. Application, scene and key
window stay active. This attribution belongs to that replay and interval, not every motion case.

Enumerating every native caret once is more expensive than the targeted queries: a same-device
dense recording raises layout-helper CPU samples from 195 ms to 314 ms. Seeding the searches
with native hit testing preserves exact boundaries but leaves endpoint-query samples at 189 ms.
Neither approach is retained.

The retained refinement copies native glyph positions only for an unadjusted mapping. It requires
printable ASCII, a monospaced font and one complete left-to-right identity run with one native
glyph per UTF-16 index. Nominal and shaped glyphs must agree; native advances must match the
font's glyph advances; positions must start at zero and remain exactly contiguous. The stored
values are native positions, never calculated cell widths. Unsupported mappings and the final
line boundary keep the original caret query. The data lives only in the temporary layout value.

One glyph per character is insufficient by itself. A real kerned Times-Roman fixture has native
carets approximately 1.03 pt away from glyph origins. Independent boundary tests retain that
counterexample, ligature interiors, native monospaced text and trailing spaces. Native API
characterizations on both host and iOS also check every printable ASCII character.

The guarded mapping reduces sampled layout-helper work from 195 ms to 88 ms in a same-device
dense replay; native caret queries have no samples in the latter recording. This is a measured
preparation reduction, not a complete motion verdict. That profiled replay still fails a later
frame-step bound: its 100 ms callback gap contains 84 ms of sampled main-thread work, including
61 ms in transaction commit and 58 ms in backing-store work. These inclusive counts overlap.
The original unprofiled acceptance suite passes all 65 cases. Required CI remains authoritative.

[CI 385](https://github.com/fardavide/granita/actions/runs/40531226511) subsequently fails motion
bounds, including the plain fixture, and a later-file scrolling setup check. Coverage stops at
that failed prerequisite and produces no numeric verdict. The native mapping reduction therefore
does not establish a complete repair.

Two further counterfactuals are not retained. Issuing alignment in the collapse update removes a
measured request stagger and reaches the final viewport earlier, but does not establish coupled
native motion; some final header lag increases. Moving the same fade mask from the complete hunk
to each row passes one profiled replay but does not reduce glyph painting: same-device dense-phase
samples in `CGSColorMaskCopyARGB8888` rise from 316 ms to 336 ms. The unchanged control fails a
105.67 pt frame step against the original 99 pt bound. A passing replay alone is not evidence for
retaining the mask change.

Making only proven offscreen text transparent is also rejected. Glyph-copy samples fall from
316 ms to 75 ms, but native glyph transparency introduces 553 ms of transparency-layer work.
The dense replay then fails the original intermediate-frame, frame-step and arrival-lag checks.
Keeping the complete string while changing its offscreen alpha is not a rendering-cost repair.

A custom text renderer was rejected. Its rasterization introduced small translated-edge color
differences, and a rounding option also failed original phone snapshots. The added translation
check uses the repository's existing 0.999 area / 0.87 perceptual image policy, calibrated by a wrong
one-pixel expected crop that fails. Native offsets, same-position restoration and vertical
position remain exact checks. No pre-existing assertion, baseline or threshold changes.

The 96- and 256-value stress payloads exceed the server's 1,000-character word-pairing cap. They are
representable by the wire model and exercise client stress behavior; the current parser emits
those long lines without segments. The original 16-value fixture remains a production-reachable
case. The repair retains all their existing motion bounds.

All 59 focused eligibility/native-layout/projection cases and all 65 original collapse and
scrolling acceptance cases pass on the guarded mapping. Package tests, both unsigned app builds
and device Release compilation also pass. Both complete instrumented iOS groups pass: 1,168
cases, including the original diff snapshots, with no failures, skips or runtime warnings. All
20 native input cases pass. Unit, both iOS groups and Ui receipts share source digest
`821005562b2f7bf83fce463ecd5b612fbe1f07fa80efc4ee4cce4d3ebd4fbc58`.

The local Mac run reports image differences, then stops producing output in its first reader
menu case. It is interrupted after the idle interval; its partial result records 80 failed cases
and one passing case. There is no successful Mac receipt or aggregate coverage verdict. The
unchanged complete Mac suite and numeric coverage gates remain required in CI.

The successful runner recording identifies the exact app process and simulator, keeps both phase
markers and records the diagnostic source digest separately from the primary required receipts.
Its temporary fixture and CI recording steps are removed after diagnosis. A fresh complete CI
attempt must validate the repair; no primary result or coverage receipt is replaced or relabelled.
