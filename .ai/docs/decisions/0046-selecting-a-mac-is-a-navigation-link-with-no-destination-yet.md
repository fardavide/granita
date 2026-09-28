# Selecting a Mac is a navigation link with no destination yet

§1's headline defect was the discovery row built from a label-and-value pair, which resolves width
pressure by dropping the "value" — here a disclosure chevron — onto its own line, 300pt from where an
indicator belongs. The row is now a value-based `NavigationLink`, which supplies the indicator, pins
it to the trailing edge at every type size, gives the correct pressed state, and draws no chevron at
all once this list becomes the split-view sidebar in M4.

The consequence is that the `Ui` layer no longer reports the selection and the composition root has
no `navigationDestination` for a discovered server, so tapping a Mac does nothing. That is what
tapping a Mac already did — the callback was a no-op, because selecting a Mac *is* pairing and
pairing brings the Keychain identity and the QR code with it. Chosen over deferring the fix until
pairing exists, which would have left a shipped bug shipped and asserted as correct by the baselines.

### Where the design review contradicted itself, and how it was read

Two places where §1's prose and its own drawings disagreed. Settled with Davide rather than by
picking whichever was read last, and folded back into `design.md` so the document no longer holds
both readings.

- **The Mac row is one line, not two.** The prose asked for a two-line limit with middle truncation;
  the frame drew one line, middle-truncated; and the paragraph below rejected "a two-line wrap with
  the chevron centred" for making a 68pt row. A two-line limit does not truncate a long device name
  at 390pt — it wraps it, producing precisely the rejected layout. One line, so every row is the same
  height.
- **The iPad measure goes around the navigation container.** The prose asked for the large title to
  sit inside the 420pt measure. iOS draws a large title in the navigation bar rather than in the
  content, so clamping the screen centres the rows and leaves the title at the window's leading edge.
  The composition root clamps the stack instead, and the snapshot suite clamps on the same side so
  the baselines assert what ships. Rejected: hand-rolling the header inside the column, which buys
  exact alignment by giving up a system control.

