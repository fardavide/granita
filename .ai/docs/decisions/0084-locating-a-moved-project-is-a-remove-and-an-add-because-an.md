# Locating a moved project is a remove and an add, because an identifier is a hash of a path

`Locate…` looks like an edit and cannot be one. Every opaque identifier in this product is derived
from a canonical path, so a project that moved is a *different* project to everything that resolves
one — the store, the API, the phone. Editing the path in place would leave a record whose identifier
no longer derives from its own contents, and the next thing to recompute one would stop finding it.

So the move is `removeProject` followed by `add`, with the name and the switch carried across because
those are the two things a reader decided. `Store` grew `removeProject(id:)` for this and for the
minus button, and it deliberately leaves worktree aliases and viewed marks alone: they are keyed by
their own path-derived identifiers, so re-adding the same folder finds them where it left them, and
nothing outside an enabled project is ever served.

**The switch survives the move, and that is the call worth naming.** A project switched on before its
folder moved comes back switched on, which is what makes `Locate…` a repair rather than a second
setup. What it beats is relocating to *off* on the grounds that a path change is security-relevant —
it is not: the reader is standing at the Mac naming the folder, which is exactly the gesture that
enabled it in the first place.

Rejected outright: making the switch's disabled state flip the project off while the folder is
missing. Turning off something a person turned on, while they are not looking, is a decision this app
does not get to make — and a project switched off by the app is indistinguishable, a week later, from
one they switched off themselves.

