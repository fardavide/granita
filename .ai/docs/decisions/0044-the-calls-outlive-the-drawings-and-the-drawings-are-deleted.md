# The calls outlive the drawings, and the drawings are deleted as they are built

The four client screens were reviewed and redrawn on 21 August 2026, against 0.0.4 as shipped. The
calls live in [`design.md`](../design.md) and the `design` skill makes consulting them binding before
any client SwiftUI. The frames live in [`design/`](../design/) **only until the screen exists**.

Two halves with opposite lifetimes, and conflating them is the mistake this entry exists to prevent.
The prose is **kept**, because a review whose alternatives are only in someone's session gets
re-litigated the first time an agent has a different idea — every call names what it beat, for the
same reason the entries in this file do. The frames are **working material**, and are removed by the
pull request that implements their section. Davide, 2026-08-21: *"We're not saving design as a
documentation, we're saving actual design for the upcoming implementation. Once implemented, they
are gone."*

What replaces a deleted frame is not nothing: it is the committed snapshot baselines, which are the
only artefact that can be compared against what was returned. A drawing kept beside them is a second
answer to a question that now has a real one, and the two drift.

§1's frames went this way in 0.0.6, with the screen. §2, §3 and §4 remain because they are not built.

### The rename sheet offers the session suggestion; it does not prefill it

The one place the design contradicts `SPEC.md` §10 outright, recorded here because that is what this
file is for. The spec says the rename sheet opens with the suggested alias prefilled. It will
instead open **empty, with the derived name as the placeholder, and the suggestion offered as a
tappable row**.

Prefilling means the reader's first act in every non-accepting case is to select-all and delete 51
characters on a phone keyboard, and a prefilled field cannot distinguish "I accepted the agent's
summary" from "I named this". Offering costs one tap in the accept case. The section footer states
what the row will read after Save and updates live, which is what makes an empty field legible
rather than mysterious. Lands with M4.

