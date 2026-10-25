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

Collapse preparation holds one pending source/successor pair and requests its typed header identity
in the same state update as the collapse. The request completion retires only its own pending pair,
independently of whether a manual gesture already released the typed scroll position. Reopening,
explicit selection and disappearance retain their cancellation paths.

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
all 59 original focused executions, including the unchanged descendant checks. This keeps header
effects composed without the separate geometry-animation barrier; the body's geometry group,
lazy stack, animation curve and every assertion remain unchanged. It is a candidate pending CI,
not a verified repair of the runner failure.

The UI runner launches a separate offline fixture application containing the production reader.
Public native scroll geometry and two code crops provide observations; only the out-of-process
UI runner supplies touch input. The fixture is absent from shipping app schemes. Its required CI
step runs after snapshot collection, with counters outside the existing coverage measurement.
