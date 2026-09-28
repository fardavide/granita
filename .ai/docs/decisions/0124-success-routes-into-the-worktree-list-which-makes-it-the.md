# Success routes into the worktree list, which makes it the first control in this app that had none

The sidebar shipped with "no way to reach it, and that is the point": pairing had no screen, so a
route to it would have been a link to a screen that cannot load. Pairing has four screens now, so
the route is built rather than deferred — a pairing that succeeds and goes nowhere is precisely the
defect the previous entry was written about, arriving one release later through the same door.

**`HttpGranitaRepository` learned to address a `PairedMac`**, rather than the composition root
assembling `https://host:port` from one. Same argument as the pairing route two files over, and it
is recorded again because it was nearly repeated: the root is the one layer no test can reach, and
"which address did the request actually go to" is exactly the question a test should be able to ask.

**The route value is the `PairedMac` itself**, and a pair of it with the Mac's name was written and
then taken out again. §5 titles the list with that name, so carrying it looked obviously right — and
nothing reads it, for the reason below, which makes it API a screen has not agreed to. This file
already has an entry about shipping exactly that, so the second one lasted an hour rather than a
release.

### The one clause of §5 this does not build is that title, and the reason was measured

`WorktreeSidebarView` titles itself *Worktrees*. §2 never says what the title should be, so that was
the implementer's choice rather than a competing decision, and §5's sentence is the only statement
on the matter — which would ordinarily settle it.

What stopped it is arithmetic rather than doubt. **A `navigationTitle` applied outside a view that
sets its own does not override it**, which was checked rather than assumed: the sidebar screen's
baseline was rendered with `.navigationTitle("Mac Studio")` wrapped around it and the suite stayed
green, so the outer one changes nothing at all. Titling the list therefore means threading a name
through §2's view, and that moves **52 committed baselines** across two suites — a re-record of
another slice's screens, in the commit that wires navigation, reviewed by an eye that cannot look at
52 pictures properly. A re-record is a design change and gets its own pass.

So the route carries the name and the screen does not wear it yet, and the modifier that would have
been a no-op is **not** left in place looking like it works. Davide's call: build it with the
re-record, or let the list stay *Worktrees* and amend §5.

