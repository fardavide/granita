# The file tree carries structure and identity, and nothing that changes while it is on screen

A row of the file selector renders a status letter, a name, `+n / -m` and a viewed checkbox, so the
obvious design hangs the whole change record off each leaf. The tree carries an identifier and a
repo-relative path instead, and the rest is joined by identifier one layer up.

Two reasons. The first is that everything omitted **churns while the shape does not**: viewed state
flips under the reader's finger, stats move on every poll, and a structure rebuilt for either is a
structure that was never really about the change record. The second is that the change record does
not exist yet — landing SPEC §4's `FileChange` here would have forced a decision on how an opaque
identifier encodes on the wire, and the spec carries no JSON example to settle it. That belongs to
M2's API contract, not to a grouping function, and guessing it here would have put a wire format in
a module that never touches the wire.

So the tree's input is its own two-field entry: an identifier to hand back when a row is tapped, and
where the file sits. The mapping from a change record is a boundary mapper, which is what boundary
mappers are for.

