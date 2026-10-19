# Header alignment ends with its animation

On 19 October 2026, an actual iOS UI test reproduced the horizontal-scroll regression introduced
in 0.22.3. It marked the pinned first file viewed, scrolled vertically into the next file, then
dragged horizontally at equal vertical coordinates. The outer viewport moved 918 points. The
same drag in a fresh review without a preceding collapse passed.

Release the explicit header scroll identity when its animation completes. Retaining that identity
allowed later hunk layout changes to realign the outer scroll with the old header request. The
completion only clears its own header identity, so a newer file-selector request keeps ownership.
Both actual-touch cases then passed, checking native pan delivery, rendered horizontal travel,
changed code pixels and vertical stability throughout the gesture.

Collapse preparation holds one pending source/successor pair. Its successor background checks
positive layout size on a subsequent animation update before starting viewport motion. The former
geometry action changed the phase that its own geometry transform read, necessarily changing the
reported readiness back to false. Removing that feedback edge removed the warning during collapse
while the existing motion, source-reopen and explicit-selection cases still passed. The animation
curve, capture window, tolerances and final position remain unchanged.

The UI runner launches a separate offline fixture application containing the production reader.
Public native scroll geometry and two code crops provide observations; only the out-of-process
UI runner supplies touch input. The fixture is absent from shipping app schemes. Its required CI
step runs after snapshot collection, with counters outside the existing coverage measurement.
