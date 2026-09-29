# The measure is released where the spine ends, and the composition root was the wrong place to say so

Design §5 puts everything before a paired Mac in a 420pt centred column, title included, and §2 puts
the worktree list in a split view with a 320pt sidebar. Those are two different measures, so the
container carries a **condition**, and from 0.4.1 that condition lived in `GranitaMobileScene` as a
flag set beside the pairing that succeeded.

**A Mac is paired with once and opened every day after, and only the first of those set the flag.**
The everyday route — tap a Mac this phone already knows, go straight to its worktrees — pushes a
`DiscoveredServer` from the discovery list's own rows and never passes through the pairing that
assigned it. So on iPad the split view opened inside the 420pt slot the pre-pairing screens use: a
320pt sidebar, roughly 100pt of detail column with the file names running off the end of it, and
white either side of the whole thing. On the phone nothing was visibly wrong, because 420pt is wider
than the phone.

**The container is now `PairingSpineScreen` and the rule is `PairingSpineNavigation`**, both in
`ClientConnectionPresentation`. The screen takes the two destinations past the spine as builders —
the remembered Mac and the just-paired one — because a `Presentation` target may not see a sibling
one, and marks both in adjacent lines with the same one-line helper, so the two ways out cannot be
given different measures and a third added later is a three-word omission next to its neighbour
rather than a missing assignment in another module. The root keeps what only a composition root can
answer: which implementation fills each protocol, and which session each list speaks over.

### The rule is an object because a rule is a sequence, and a view body is one frame

`PairingSpineNavigation` holds the path and answers one question — how wide the container may draw.
It is split out rather than left as two `@State` properties for the reason the defect happened: the
measure follows from a *sequence* of pushes and pops, a rendered baseline can only photograph one
frame of a sequence, and a `Main` module is exempt from both coverage rows. As an object in
`Presentation` it is a plain host test, and the sequence that has to hold — open a Mac, leave the
spine, come back, open a different Mac — is eight assertions rather than a thing nobody can run.

The reset lives in the setter of `path` rather than in an `onChange` in the view, because emptying
the path is the *only* signal there is that the reader went back: the button that does it is the
system's and nothing of ours is told it was pressed. The two ways out of the spine are then a method
reference and an `onAppear`, so the view body has no closure a test cannot reach.

### The flag cannot be read off the path, which is why it is written rather than derived

`NavigationPath` is type-erased on purpose — it is what lets every destination be declared beside the
link that reaches it — so the stack cannot be asked what it is showing. A Mac already paired with and
a Mac about to be paired with are the *same value* at depth one, and which of the two a push reaches
is decided inside `ChosenMacScreen` from a set that changes. So there is nothing to derive from, and
the honest form is a flag written at the two places that know.

### The baseline photographed the defect and stayed green through it

`PairingSpineSnapshotTests` existed precisely to assert that a value put on the path comes back as a
screen rather than as the system's missing-destination placeholder — and it rebuilt the root's stack
itself, with `.frame(maxWidth: ServerDiscoveryView.contentWidth)` hardcoded around it. Its
`a-mac-already-paired-with` iPad baseline is therefore a picture of the destination clamped to 420pt,
recorded as the truth. **A replica of the thing under test asserts the replica.** The suite now
renders the real `PairingSpineScreen` and hands it stand-ins for the two destinations, so the width a
push lands at is measured; the two iPad baselines were re-recorded, and they are the diff that says
what was wrong.

`a-mac-just-paired-with` is new beside it, and the pair is the assertion: the same arrival, at the
same width, reached by the other route. The route that *worked* had no baseline at all until now,
which is the other half of why nothing noticed.

`startingAt:` is a required parameter rather than a defaulted one for the same reason: it is what
lets a baseline open the stack at the push it is photographing, and the root passes an empty path
explicitly.

