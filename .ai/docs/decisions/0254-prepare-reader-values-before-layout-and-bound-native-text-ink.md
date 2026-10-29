# Prepare reader values before layout and bound native text ink

The complete-text control in [0250](0250-keep-text-content-updates-out-of-file-layout-animation.md)
did not resolve the required CI failures. A controlled local fixture retained the original 160
delete/add pairs, 396pt travel, 1.2s observation and every motion assertion, while scaling each
dense line from 256 to 4,096 values. Its first callback arrived after 2.139s, too late to observe
the animation. This is a diagnostic overload, beyond the parser's normal pairing limit, rather
than a new shipping fixture or a revised performance budget.

Native recordings identified repeated width-zero line preparation, synchronous text/ruler
projection and native painting. Removing duplicate preparation and reducing validation overhead
alone still failed: the latter capture had a 1.133s initial gap followed by a second stall,
including 853ms exclusively in native glyph-mask copying. Those controls were insufficient.

Ready reader content now carries immutable, font-independent line and ruler values constructed
together from its source. Initial fetched batches prepare these values away from the main actor;
publication preserves the reader's current viewed/open choices. The existing fetch-ownership
boundary remains before asynchronous decoration. Raw core/wire values remain unchanged. Native
font measurement, attributed rendering and platform geometry stay in Ui. Split or highlighted
rulers retain their existing projection where their effective text can differ.

The painting overlay waits for a measured nonzero viewport. For supported ASCII, native Text
may paint a window of source characters: an offscreen prefix becomes the same number of spaces,
and a distant suffix is omitted. The original full line still determines scrolling width and
accessibility. Acceptance requires native copied positions and the terminal native caret to
match the original; unknown or unsupported mapping retains complete native text. This supersedes
the complete-character rendering decisions in [0248](0248-measure-visible-word-backgrounds-before-native-text.md)
and [0250](0250-keep-text-content-updates-out-of-file-layout-animation.md), retaining their native
geometry fallbacks and identity content transitions. No translated prefix or layout cache is used.

The same local overload now passes: first callback 0.529s, successor arrival 1.141s, with the
original intermediate-frame, step, alignment and descendant checks intact. Its recorded phase
contains 762ms sampled main-thread work and 16ms in CoreGraphics. Both recording runs restore
their source fingerprints. All 66 original interaction executions and all 76 saved-image
executions also pass locally, with no baseline, timing, physical-bound or coverage-gate change.
These results establish a local before/after repair; they do not establish a passing remote CI
attempt or TestFlight delivery. Temporary profiler tools and the overload fixture are removed
before the final shipping validation.
