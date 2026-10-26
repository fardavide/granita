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

A custom text renderer was rejected. Its rasterization introduced small translated-edge color
differences, and a rounding option also failed original phone snapshots. The added translation
check uses the repository's existing 0.999 area / 0.87 perceptual image policy, calibrated by a wrong
one-pixel expected crop that fails. Native offsets, same-position restoration and vertical
position remain exact checks. No pre-existing assertion, baseline or threshold changes.

The 96- and 256-value stress payloads exceed the server's 1,000-character word-pairing cap. They are
representable by the wire model and exercise client stress behavior; the current parser emits
those long lines without segments. The original 16-value fixture remains a production-reachable
case. The repair retains all their existing motion bounds.

All 34 focused geometry/native-layout/projection cases, both translated-image cases and the
unchanged dense motion acceptance pass on the batched path. All 76 original diff snapshots and
both complete instrumented iOS groups pass on the final sources: 1,168 cases with no failures,
skips or runtime warnings. Package tests, both unsigned app builds and device Release compilation
also pass. All 20 native touch cases pass. Unit, both iOS groups and Ui receipts share one source
digest. The local Mac run finishes red, with image differences, a model-settling failure and a
640×460 content-minimum observation against the unchanged 640×480 assertion. It also reports
MDB_MAP_FULL; no cause is inferred from that log alone. The failed suite produces no successful
Mac receipt or aggregate coverage verdict. Required CI remains pending.
