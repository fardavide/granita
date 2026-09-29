# A file drawn shut is not fetched, which is what makes *Load diff* true

`ContinuousDiffLoading` gained a third set beside `held` and `inFlight`, and **unlike `held` it
shrinks**: a reader opening a bar takes a file out of it.

Without it the affordance is a label. `SPEC.md` §10 puts *Load diff* on a file over 500 diff lines by
name, and a phone that had already spent a batch slot on 1,558 lines nobody asked to see would be
offering to do what it had done. It also pays for itself on the ordinary screen: in a change set the
reader has been through once, every file they read is shut, and those are exactly the diffs not worth
twenty seconds of somebody's network.

The other half is that opening one **fetches it**, in the model, as a batch of one. Without that,
pressing a bar leaves a header over a blank stretch that nothing ever fills — the dead control this
project shipped for eight releases, arriving through the door built to stop it.

> A mark set while the file is on screen costs nothing, because its diff is already in hand. What the
> rule defers is the files that were read in an earlier sitting, which is the case it is for.

