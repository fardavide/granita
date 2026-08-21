# Granita docs

Narrative: how it is built, **why**, and where it is. Actionable rules live in
[`../skills/`](../skills/) instead — a rule an agent must follow belongs in a skill, a reason a
choice was made belongs here.

| Doc | Holds |
|---|---|
| [`architecture.md`](architecture.md) | The two halves, the layer rules and how the compiler enforces them, dependency inversion, opaque identifiers |
| [`decisions.md`](decisions.md) | Why each choice was made and what it beat — including every deliberate departure from `SPEC.md` |
| [`status.md`](status.md) | Milestones, what exists, what Davide still owns |
| [`verification.md`](verification.md) | What the spec's verify-first pass found against the real environment, with numbers |
| [`design/`](design/) | Frames as Claude Design returned them; the calls they carry live in prose alongside |

[`../../SPEC.md`](../../SPEC.md) is the specification itself, and it is the authority on *what* to
build. `decisions.md` is the authority on where this repository knowingly differs from it.

## For agents

- **Read `architecture.md` and `decisions.md` before any non-trivial change**, so you do not break a
  layer boundary or re-open something already settled.
- **Record a decision here whenever a choice would be expensive to reverse** — layering, an error
  model, a dependency, a naming convention. Append it to `decisions.md`, newest last, and name the
  alternative it beat: a decision without its discarded options gets re-litigated within a month.
  When a fork is settled with Davide, the answer becomes an entry in the same pull request.
- **Update `status.md` when a slice lands**, and `architecture.md` only when the structure actually
  changes.
- **Describe concepts and contracts, not type or function names.** Names rot on rename; the shape
  they implement does not.
