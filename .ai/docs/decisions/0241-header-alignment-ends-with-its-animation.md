# Scroll requests yield to manual scrolling

On 19 October 2026, an actual iOS UI test reproduced the horizontal-scroll regression introduced
in 0.22.3. It marked the pinned first file viewed, scrolled vertically into the next file, then
dragged horizontally at equal vertical coordinates. The outer viewport moved 918 points.

Clearing the header identity after animation made that case pass locally and in CI, but CI also
reproduced a 2,095-point jump in a fresh review without a preceding collapse. The optional identity
binding could not represent the reader's position inside a file reliably across hunk layout changes.

Use SwiftUI's typed scroll position for both file selection and header alignment. Explicit requests
still identify a file or header, without subscribing to nearest-section identity updates. Clear
each animated request on completion if no newer destination has replaced it; later hunk layout
must not realign a completed request. Seed an explicit file selection on first layout; an ordinary
review has no seeded target. One request function serves selector jumps, collapse and source
reopening, preserving their distinct header/section destinations and animation curves.

Collapse preparation holds one pending source/successor pair. Its successor header reports geometry
from inside its geometry group; the transform reads only the proxy. The first upward change, or a
header already at or above the viewport, starts the typed header request. A waiting/scrolling phase
allows exactly one request while retaining the pair for cancellation. Request completion retires
only its own pending pair, independently of whether a manual gesture already released the typed
scroll position. Reopening, explicit selection and disappearance retain their cancellation paths.

The previous successor background waited for positive layout size and a Timeline animation update
before requesting viewport motion. CI run
[40011176859](https://github.com/fardavide/granita/actions/runs/40011176859) still recorded a case
where the viewport arrived with 551 pt of successor travel remaining; successive native samples
showed the header continuing to move afterwards. Moving the typed request into the collapse update
passes all 59 focused native executions and all six actual-touch tests locally. The obsolete
Timeline background is removed. This local result is not yet proof that CI's phase difference is
repaired. The animation curve, capture window, assertions, tolerances and final position remain
unchanged; CI still judges the original motion and header-coherence limits.

CI run [40060044107](https://github.com/fardavide/granita/actions/runs/40060044107) rejected the
synchronous candidate too: five motion cases reported eight issues, with up to 621 pt of successor
lag. The same run passed all actual-touch and native adapter cases. The deferred hand-off is
therefore not a sufficient explanation. Native animation-clock attachments retain the original
samples and assertions, and a separate recorded replay runs only after the required motion shard
fails. Its video and result bundle are diagnostic artifacts; they do not replace the required
suite verdict or any coverage inputs.

The next diagnostic run, [40133024145](https://github.com/fardavide/granita/actions/runs/40133024145),
recorded the same delayed header position in both model and presentation layers: at viewport
arrival one header still had 439 pt to travel. The separate replay video showed the visible
misalignment too. This rules out a compositor-only explanation. Removing the header geometry
group locally reduced the lag, but removed the nested layer observed by the existing coherence
assertion, so that experiment remained red. Replacing that group with a compositing group passes
all 59 original focused executions, including the unchanged descendant checks, but CI run
[40171825933](https://github.com/fardavide/granita/actions/runs/40171825933) still rejects seven
motion cases. The header-only compositing candidate is therefore reverted; both header and body
keep their geometry groups.

A local successor fixture with 96 changed values per line reproduces a 159 pt frame step against
the existing 99 pt limit, while both views reach their final positions inside the unchanged
1.2-second window. Segmented line preparation was calculating Unicode display columns for every
character even when the whole line contained no tabs. Those columns only affect tab stops. A
line-wide tab check now skips that calculation for tab-free lines; any tab retains the original
ordered expansion and column propagation. Concatenation and cumulative character-count ranges
stay unchanged, including graphemes spanning segment boundaries. The same long-line fixture passes
in isolation after this optimization, but the complete focused suite still rejects a 102 pt frame
step with the original header grouping and a 140 pt step with the compositing candidate. The first
optimization is therefore insufficient. Recounting the growing prefix after every segment adds
another avoidable scan. The cumulative count is now reused between segments; only ASCII without
CR/LF uses additive byte counts. Every other line still recounts the concatenated string, preserving
graphemes spanning segment boundaries and the original changed ranges. These two optimizations
alone still fail the frame-step limit.

A state-free geometry probe inside the header group reports intermediate upward positions before
their next native presentation sample, matching those samples after the viewport-origin adjustment.
The pending request now waits for that measured movement rather than first appearance. Combining
this handshake with both text optimizations passes all 60 focused executions. Removing the text
optimizations, or retaining only the tab optimization, restores a 120 pt frame step against the
unchanged 99 pt limit. The new fixture joins the original motion cases with their curve, capture
window, frame-step, successor-lag and descendant-coherence assertions unchanged. CI verification
remains pending.

The instrumented shard passes all original cases but still rejects the long-line fixture: one
116.7 ms callback gap produces a 101.3 pt viewport step. A sampled main-thread stack identifies
repeated character-index walks while applying word highlights. Each changed range now advances
from the previous range's end instead of recounting both offsets from the start. Ranges remain
ordered character offsets, including empty ranges and Unicode text. All 62 focused executions
pass, including viewed and manual collapse into a short successor. The rebuilt instrumented
motion shard also passes all 61 test functions in 17 suites, with no failures or skips and a
complete coverage receipt matching the unit source digest. The other iOS shard passes 21 functions;
all six actual-touch and eleven native-input cases also pass with matching complete receipts.
Required CI confirmation remains pending; no motion limit or baseline changes.

The UI runner launches a separate offline fixture application containing the production reader.
Public native scroll geometry and two code crops provide observations; only the out-of-process
UI runner supplies touch input. The fixture is absent from shipping app schemes. Its required CI
step runs after snapshot collection, with counters outside the existing coverage measurement.
