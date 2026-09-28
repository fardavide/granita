# Two states of §5 that the frames do not draw, and one they draw that is now false

The false one first: **the plaintext warning under the QR is not built.** It was true of 0.0.6 and
0.0.7 landed TLS and a real `spki=`; `design-mac.md` already says so, and this is the pull request
that had the chance to reintroduce it and did not.

The two that had to exist:

- **A code that could not be made.** The link is signed by an identity out of the login Keychain,
  which can be locked or half-removed, and a pane that silently showed nothing would be the same
  defect as the dead row this project shipped for eight releases. Our sentence — *No pairing code
  could be made* — with the Keychain's own words underneath and a **Try Again**, which is this
  product's failure idiom everywhere else.
- **A code being made.** `.preparing` is the honest state before the first one lands, because reading
  the identity is real work. It is not a placeholder for something unbuilt.

**Whether a code has expired is decided from a `now` the pane is handed**, not from a clock read
inside `body`. Same reason the connection log's elapsed time is handed in: a state derived from the
moment of drawing is a state no baseline can photograph, and *expired* is precisely the state that
matters most. The pane's `TimelineView` steps once a second rather than the log's once a minute,
because the smallest thing on screen here is a seconds digit.

**The window fits it, but only just, and the stack had to be tightened to make that true.** The first
render put *Expires in 1:46 / Single use* below the fold of the 560pt window design §2 sized from
this pane — ten points of spacing between each of five children was the whole difference. Recorded
because the next person to add a line here will spend it.

**`Revoke` is red on its label rather than tinted.** A tinted bordered button fills its bezel, and a
row with a solid red block in it reads as an alarm that has already gone off rather than as something
to press.

**The date reads *paired August 3* rather than the review's *paired 3 August*.** The order is
`Date.FormatStyle`'s under the reader's locale, and the baselines pin `en_US_POSIX`. Forcing
day-before-month would be overriding a system decision to match the language the review happens to be
written in.

