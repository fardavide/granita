# The worktree sidebar ships with no way to reach it, and that is the point

M4's list needs a paired Mac. Pairing has no frames, so it has no screen, so **nothing routes to this
one** — not a row, not a tab, not a debug entry. `ClientAppMain` builds the browse and stops exactly
where it did.

That is the rule rather than an exception to it. A control ships if it works, is absent, is disabled
and says why, or explains that what is behind it is not built. **Absent is a legitimate state; a link
to a screen that cannot load is not**, and this project shipped the second one for eight releases.
The alternative offered and declined was a debug-only route, which is the same defect with a
smaller audience.

The consequence is that **none of this screen's controls has ever been pressed**, which is the same
honest state the Mac's ten are in and for a different reason: there the grant is missing, here the
route is. Every one of them is asserted at the model — the two swipes, the menu's picker and toggle,
the footer, Try Again and Show them anyway — and a rendered baseline cannot say whether anything is
behind any of them. They are pressable the day pairing lands, and that is when they get pressed.

**A row still has to do something the moment the screen is reachable**, so it does: selecting one
pushes `WorktreeNotReadyView`, which names the worktree and says the file list is being built. It is
declared in the same file as the links that reach it, and it goes when design §3 arrives — the same
shape, and the same reason, as `PairingNotReadyView`.

