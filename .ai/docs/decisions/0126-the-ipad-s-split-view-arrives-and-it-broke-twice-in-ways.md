# The iPad's split view arrives, and it broke twice in ways only a photograph could show

Design §2's other half — a 320pt sidebar and a *Choose a worktree* detail column — has been waiting
for "whichever composition root presents this screen", and pairing brought it. Two things this file
would otherwise have recorded as reasoning are recorded as measurements instead, because both of the
first two attempts compiled, read correctly, and rendered a broken screen.

**A collapsed split view inside a navigation stack draws its chrome and none of its content.** The
first build let the phone take the documented collapse — a split view in a compact width folds into
its sidebar — and the iPhone baseline came back with the title, the toolbar menu and *no rows at
all*. It has to be inside a stack, because §5 requires that back returns to the Mac list. So the
compact width is a branch rather than a collapse: the phone gets the sidebar screen directly, which
is what the fold was supposed to produce, and both widths are photographed. The question asked is
the horizontal size class and not the device, because an iPad in a narrow multitasking width is the
phone's layout too.

**A split view keeps the destinations declared inside its columns.** The list's rows have been
value-based links since §2 shipped, with their destination declared in the sidebar screen beside
them — the placement this project adopted after shipping a row that did nothing. Put the split view
around that screen and the declaration no longer reaches the stack outside it: a worktree pushed on
the root's own path rendered the system's yellow missing-destination placeholder. That is the same
defect returning through the door that was built to keep it out, and a snapshot found it because
this suite photographs the pushed value rather than the resting screen.

So **the destination is declared twice, on both containers that can claim a tap**, written once as
one modifier so the two cannot drift. The stack's half is asserted by a baseline; the split view's
half cannot be, because no test kind that runs here can tap a row and only a finger can say which
container SwiftUI hands the value to. Both lead to the same screen, so the one outcome that is ruled
out is the row going quiet. It collapses back to one declaration the day design §3 gives the detail
column something of its own to show.

### The measure stops at the paired Mac, which is two designs meeting in the root

§5 says "everything before a paired Mac lives in a 420pt column, title included" and §1 says that
measure goes around the navigation container rather than around the screen. §2 then puts the list
itself in a split view whose sidebar is 320. Both hold, and they hold in the same container, so the
root's clamp is now conditional: a 420pt cap around a two-column split view would leave an iPad
reading its worktrees through a phone-shaped slot.

**It cannot be read off the path**, which is why the root gained a second piece of navigation state
beside it. `NavigationPath` is type-erased on purpose — that is what lets each destination be
declared beside the link that reaches it — and a paired Mac and a Mac about to be paired with both
sit at depth one. Back out of the list is watched on the path emptying rather than reported by the
screen, because the button that performs it belongs to the system and tells us nothing.

### Two smaller calls in the same commit

**The row's name moved from the screen to the model.** `WorktreeSidebarScreen` resolved the tapped
worktree's display name in a private helper; the detail column needs the same answer, and a second
copy of a lookup is how two containers come to disagree about what was opened. `displayName(of:)`
is on the model with three tests — the alias the row showed, a worktree that left the list between
the tap and the push, and a state holding no rows at all — which is two more assertions than the
helper ever had.

**The handshake's two branches are spelled out.** `attempt.pin.map(...) ?? UrlSessionHttpTransport()`
was correct and said nothing: the label that names trust on first use had been left to its default,
in the one line of the composition root where getting it wrong pins nothing and looks identical.

