# The Mac's design is recorded against a release the review had not seen

Claude Design drew the Mac's six surfaces on 21 August 2026 against 0.0.6, and 0.0.7 landed in the
same week. Two of the five premises the review overturns were repaired by that release independently:
the connection log's source address and the six-word code's redeemability. A third — the plaintext
warning it moved to sit under the QR — is obsolete, because TLS and a real `spki=` shipped in 0.0.7.

[`design-mac.md`](../design-mac.md) therefore records the review's calls **as corrected**, with a table
saying which premises still stand, rather than as returned. The frames stay as working material until
each section ships.

This is the `design-handoff` skill's rule doing its job in the direction it was written for: a return
is a recommendation, not a decision, and where a drawing and the code disagree the code is checked
before either is believed. Building the drawing as returned would have reintroduced a warning telling
a reader their pairing link is unencrypted when it is not — which is worse than no warning, because
it is the one screen where a reader is deciding whether to trust something.

Rejected: asking Design for a redraw against 0.0.7 before building anything. Four of the five calls
are untouched by the release, the two that changed are both *deletions*, and a second round trip to
delete a warning would have blocked the whole milestone on a question already answered.

