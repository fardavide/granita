# The merged Mac app keeps the server's bundle identifier, and the camera does not come with it

Issue [#97](https://github.com/fardavide/granita/issues/97) joins *Granita Server* and *Granita
Client* into one bundle, and the design return of 23 September 2026 answered it surface by surface in
[`design-mac.md`](../design-mac.md) §8. Four of its calls are expensive to reverse and belong here rather
than only there.

**The surviving bundle identifier is the server's.** Its Keychain TLS identity is what **every paired
phone already pins**, and its login item and Local Network grant are registered to it — so taking the
Client's identifier instead would silently unpair every phone in the world and re-prompt for local
network access on a machine that had been serving for months. What the merge loses is the Mac
Client's own Keychain of remembered Macs, which is a store with almost nobody in it, because that
build was never shipped. **This is the cheapest thing on the list to get right and the most expensive
to get wrong**, and it is not visible from either app's source.

**The camera leaves.** `GranitaMobileMac.entitlements` is not merged into the server's and
`NSCameraUsageDescription` stays in the phone's `Info.plist` alone, so a remote Mac is paired with the
six words rather than a QR code. It beat keeping the camera for parity with the phone. Two reasons,
and the second is the one that decided it: to scan, a reader would have to carry a laptop round to
face another Mac's display; and `com.apple.security.device.camera` would otherwise land **on the one
process that listens on a socket and execs `git`**. The stated cost is real — the six-word path is
`trustingFirstAnswer` and pins whatever key answered, where the QR carries its pin in the link — so
on a home network this is a first-use trust decision rather than a verified one. Reversing it means
re-adding an entitlement to a shipped, notarised, unsandboxed binary.

**The file selector is an inspector because the split view has no case for it.**
`NavigationSplitViewVisibility` offers `.all`, `.doubleColumn` and `.detailOnly` and **nothing that
hides the middle column alone**, so a third split-view column would leave `DiffPaneLayout`'s existing
`showsSelectorColumnToggle` fold with nothing to bind to — and with no worktree chosen the window
would show two empty columns. `.inspector` is the only Mac container that folds on its own. This is a
fact about SwiftUI rather than a preference, and it is why the obvious answer is the wrong one.

**One window, not one per worktree.** Two agents on one task is a genuine reason to want two diffs
side by side, and it lost anyway: the Client has one list model per screen and one review store per
worktree, so two windows editing the same viewed marks and comments is a synchronisation problem
nobody has designed. The cheap later form is *Open in New Window* on a row's context menu over a
`WindowGroup(for: WorktreeId)`, which is additive — so deferring costs nothing and building it now
would commit the review store to a shape it has not been tested in.

**And one thing that is a bug the merge creates rather than a call.** The merged process browses
`_granita._tcp` while advertising it, so **This Mac will discover itself** under its Bonjour name and
offer a second route to its own worktrees through TLS, a pin, and a pairing with itself. The browse
has to drop the instance the server registered. Nothing in either app today has any reason to do
that, because no process has ever done both.

### Two departures from `SPEC.md`, both in §2

§2 locks the macOS UI as *"`MenuBarExtra` plus `Settings` scene, `LSUIElement` true"*. A window a
reader sits in for an hour is neither, and `LSUIElement` becomes false — the app gains a Dock icon and
a ⌘-Tab entry. §2's target table also gives `GranitaMobile` as `[iOS, iPadOS]` and `GranitaMac` as
`platform: macOS`; issue [#73](https://github.com/fardavide/granita/issues/73) departed from that by
adding a third destination, and this departs again in the other direction, **ending closer to what the
spec drew than the intermediate state did**.

The consequence the spec does not cover is the one worth writing down: **closing the window must not
stop the server.** A SwiftUI app whose only window scene is closed can terminate, and here that is a
server that stopped serving for a reason its owner cannot see. No snapshot can photograph it, so it is
a `GranitaMacUiTests` case — open the reader, close it, assert the status item is present and the host
still serving.

