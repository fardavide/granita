# The unified reader shares local storage and a persistent window anchor

The implementation of [#97](https://github.com/fardavide/granita/issues/97) and
[#91](https://github.com/fardavide/granita/issues/91) follows the returned Mac design. The expensive
product calls remain in [0230](0230-the-merged-mac-app-keeps-the-server-s-bundle-identifier-and.md).

**This Mac and a remote source are distinct values.** The remembered selection carries the source,
the worktree's opaque identifier and its captured display name. Changing sources clears the previous
worktree and changes the screen identity, cancelling its reads. Discovery omits the local advertised
instance; remembered remote names survive a browse with no results or a permission refusal.

**Local reviews have one durable owner.** The reader's review adapter uses the same repository and
JSON document as the server. Its in-memory cache supports the existing synchronous view contract;
it is not another UserDefaults store. Initial local reads reconcile from that document. Reconciliation
waits for pending writes and preserves edits made while the read is suspended, so opening or refreshing
a review cannot replace a new edit with an older copy. Remote reviews retain their existing HTTP
reconciliation and offline cache.

**The local source does not depend on a listening socket.** Starting, stopped and failed hosts still
permit local reads. Another process holding the store is the exception: the reader names that holder
and leaves the source menu available without writing into its document.

**Window requests live in the status label's render tree.** The old accessory app held its opening
actions in an invisible window. In the regular unified app, the native startup test repeatedly found
no Settings window and the invisible opener's launch callback did not run. Explicit launch behavior,
removing the delegate and making the old opener visible did not repair that test. Holding the actions
behind the status label did: the same native test passed in 4.263 seconds. There is no invisible
window or activation-policy switch left. The status label handles menu requests and the delegate's
Dock reopen notification; the reader remains a single suppressed, unrestored window. The startup
spike and control tests exercise this wiring rather than assuming a scene declaration is a working
door.

**Mac containers change without changing the phone's route.** The worktree list binds selection and
the detail renders directly; the phone keeps its navigation links. Files and review use one native
inspector on the Mac. Empty changes do not open an empty inspector, and an open review wins that slot.
Code-size commands adjust the active unified or split preference only, clamp to the existing 8–17pt
range and restore its system choice. The phone's defaults remain unchanged.

**A hidden quiet row is still a known worktree.** Selection is resolved against the full worktree
inventory rather than the visible sidebar projection. Hiding quiet rows cannot turn the selected
worktree into a missing worktree; only removal from the inventory shows the remembered-name state.

**Refresh resumes visible cards with unchanged identities.** Replacing their diff entries does not
run SwiftUI's appearance callback again. The model resumes its bounded batch, and a visible card
reports a change in readiness so awaiting cards above the last reported position can resume too.
Ready or failed arrivals do not request another batch. Unit regressions cover these boundaries;
the final native two-file effect check remains pending after Davide reclaimed the desktop.

**Behavioural fixtures own their preferences.** A launch argument selects a disposable defaults
suite, alongside the existing temporary document and listener. Selection, appearance, list settings
and diagnostic settings use that same suite; teardown removes it without clearing the installed
app's defaults. Ordinary launches use the installed app's existing domain.

**Reader snapshots include the window's native composition.** AppKit's bitmap cache loses vibrant
sidebar and inspector foregrounds even with a compatible bitmap, pinned appearances and controller
hosting. A runner comparison shows those colours in WindowServer's composition. The capture therefore
uses the exact fixture window identifier and owning process through ScreenCaptureKit's current-process
content API, which requires no Screen Recording consent. It crops to the hosted content, keeps a
fixed two-pixels-per-point raster and excludes the cursor, shadows and child windows. It never captures
a display or another process's window, changes machine settings, or substitutes production colours.

Reader, source, menu and pairing subjects share the existing Mac snapshot bundle. Their committed
baselines come from the CI runner. Native acceptance, coverage and publication status belong in
`status.md` and the active plan, not in the design calls above.
