# Granita docs

Narrative: how it is built, **why**, and where it is. Actionable rules live in
[`../skills/`](../skills/) instead — a rule an agent must follow belongs in a skill, a reason a
choice was made belongs here.

| Doc | Holds |
|---|---|
| [`architecture.md`](architecture.md) | The two halves, the layer rules and how the compiler enforces them, dependency inversion, opaque identifiers |
| [`decisions.md`](decisions.md) | Why each choice was made and what it beat — including every deliberate departure from `SPEC.md` |
| [`design.md`](design.md) | The client's four screens, the control each one must use, and every call with the alternative it beat — the design sheet the round trip writes into |
| [`design-mac.md`](design-mac.md) | The same for the Mac's seven surfaces: the status item, the window, and the five Settings tabs |
| [`design-review-settings.md`](design-review-settings.md) | The phone's Settings sheet, the sync caption, and the Mac's sixth tab — the calls from the 17 September 2026 return, built in 0.15.0 |
| [`design-appearance.md`](design-appearance.md) | That sheet's fourth section and the chooser it pushes: the app's appearance, the code's colours, and why three of the five drawn theme pairs ship |
| [`design-side-by-side.md`](design-side-by-side.md) | The split view: why a paired run and not a file, the twenty-character floor, and the five places the build departs from the return |
| [`design-code-size.md`](design-code-size.md) | The code's own size in two halves, why *Follow system* clamps the split rather than bending its floor, and the two sentences a refused split carries |
| [`status.md`](status.md) | Milestones, what exists, what Davide still owns |
| [`verification.md`](verification.md) | What the spec's verify-first pass found against the real environment, with numbers |
| [`design/`](design/) | Frames as Claude Design returned them; the calls they carry live in prose alongside |

[`../../SPEC.md`](../../SPEC.md) is the specification itself, and it is the authority on *what* to
build. `decisions.md` is the authority on where this repository knowingly differs from it.

## For agents

- **Read `architecture.md` and `decisions.md` before any non-trivial change**, so you do not break a
  layer boundary or re-open something already settled.
- **Read the relevant section of `design.md` before writing any client SwiftUI**, or of
  `design-mac.md` before any of the menu bar app's. The screens are drawn and each call names the
  alternative it beat, so choosing the other one is re-opening a settled question rather than
  exercising judgement. The `/design` skill holds the actionable form.
- **Record a decision here whenever a choice would be expensive to reverse** — layering, an error
  model, a dependency, a naming convention. Append it to `decisions.md`, newest last, and name the
  alternative it beat: a decision without its discarded options gets re-litigated within a month.
  When a fork is settled with Davide, the answer becomes an entry in the same pull request.
- **Update `status.md` when a slice lands**, and `architecture.md` only when the structure actually
  changes.
- **Describe concepts and contracts, not type or function names.** Names rot on rename; the shape
  they implement does not.
