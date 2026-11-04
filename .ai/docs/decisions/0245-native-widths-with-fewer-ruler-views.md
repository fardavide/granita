# Native widths with fewer ruler views

The hunk's horizontal ruler measures representative printable ASCII lines with native text, once
per rendered weight. Every line containing any other scalar keeps its own native measurement.
Representatives use the effective drawn text after tab expansion and highlighting fallback, keep
the first longest line per weight, and retain input order. Split-block travel keeps its existing
formula and contributes its maximum once. Painting, viewport tracking and collapse animation stay
unchanged.

The previous ruler created a hidden native text view for every full row, including rows outside
the vertical viewport. This preserved offscreen horizontal travel but added eager layout work
while a collapsed file's successor mounted. A CPU sample of the CI-built application replayed
locally showed substantial SwiftUI graph and layout work. The four CI motion failures did not
reproduce locally, including when replaying the same compiled products; this optimization is not
by itself proof that those failures are repaired.

Replacing native measurement with column arithmetic was rejected after an app-hosted experiment.
At 11 pt, 264 ASCII columns measured 1,795.33 pt against the gutter formula's 1,742.4 pt; 288 CJK
columns measured 1,543.67 pt against 1,900.8 pt. Column counts therefore cannot determine exact
horizontal travel or reliably rank mixed-script lines. No font constant or Unicode classification
changes as part of this repair.

The pure representative-selection policy has direct package tests, including first ties, both
weights, absent ASCII groups, control characters and duplicate Unicode lines. A native acceptance
test compares horizontal content width with independently measured text plus the existing 12 pt
trailing space. Its widest candidates start below the viewport; 32 cases cover four code sizes,
ASCII punctuation and spaces, tabs, mixed CJK/ASCII ranking, combining characters, emoji,
controls, highlighting fallback and conflict markers. The original motion, crop, scrolling and
file-selection assertions remain unchanged. Baselines, coverage scopes, ratchets and tolerances
remain unchanged; CI still decides whether the original collapse-motion failure is resolved.
