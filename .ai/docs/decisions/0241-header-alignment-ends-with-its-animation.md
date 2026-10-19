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

Collapse preparation holds one pending source/successor pair. Its successor background checks
positive layout size on a subsequent animation update before starting viewport motion. The former
geometry action changed the phase that its own geometry transform read, necessarily changing the
reported readiness back to false. Removing that feedback edge removed the warning during collapse
while the existing motion, source-reopen and explicit-selection cases still passed. The animation
curve, capture window, tolerances and final position remain unchanged. CI still judges the original
motion assertions; passing a local run does not waive its frame-step or header-coherence limits.

The UI runner launches a separate offline fixture application containing the production reader.
Public native scroll geometry and two code crops provide observations; only the out-of-process
UI runner supplies touch input. The fixture is absent from shipping app schemes. Its required CI
step runs after snapshot collection, with counters outside the existing coverage measurement.
