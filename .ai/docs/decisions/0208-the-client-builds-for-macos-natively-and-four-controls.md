# The Client builds for macOS natively, and four controls stopped being dead the same day

[Issue #73](https://github.com/fardavide/granita/issues/73). The Client had two destinations and ran
on a Mac through Apple's "Designed for iPad" translation of the unmodified iPadOS binary. It has
three now, in regular SwiftUI rather than Mac Catalyst — the menu bar app already proves that stack
works native on macOS, and the Client follows it rather than the compatibility bridge.

### The portability half was already done, and nobody had noticed

The issue's own description says there is no `#if os(macOS)` branch anywhere in the Client. That was
true when it was written and had stopped being true before it was picked up. More than that:
**`swift build` compiles the entire Client graph for macOS today** — it is the host, which is what
lets `make test` run with no simulator — so every `Domain`, `Data`, `Ui` and `Presentation` target
under `Client/` has been building for the Mac for as long as the package has had two platforms. What
was missing was never portability. It was a destination.

So the target change is two lines — `supportedDestinations` gains `macOS`, and `make build` gains a
fourth invocation so the sanctioned command is what checks it — and the Mac destination compiled
clean on the first run, with no error and no warning the iOS destination does not also emit.

### What the destination broke was four premises written as behaviour

Every one of the four sites below carried a comment saying, in its own words, *nothing on macOS ever
constructs this*. Each was true. Each stopped being true the moment the target existed, and each then
described a control that looks operable and silently does nothing — the defect this project treats as
worse than a crash, arriving through the one door no compiler watches: **a platform, added under
code written on the assumption that the platform would never run it.**

- **`UiKitReviewPasteboard.copy` was an empty `#if`.** The filled indigo *Copy review* button turns
  green for two seconds on success; on a Mac it turned green having copied nothing.
- **`openSettings()` was an empty `#if`.** Three screens offer it, each one at the moment the reader
  has been told a permission is missing.
- **`UiKitDiagnosticPasteboard` threw `.unavailable`.** The least bad of the four, because it at least
  reports — but the report is an error screen reached by pressing a button that works everywhere else.
- **`CameraPreviewView` drew `Color.black`.** The worst of them: design §5 orders the camera first, so
  the primary way into this product was a viewfinder that drew nothing and never said why.

None of the four is a screen a design has drawn for a Mac window, and none of them needed one — the
question each answers is *does pressing this do the thing it says*, which a drawing cannot settle
either way.

### The pasteboards are named, and that is what took them out of the exempt set

`UiKitReviewPasteboard` was documented as *"exempt in the coverage report rather than untested"*,
because executing it in a test process means writing into the developer's own clipboard and asserting
it means reading that clipboard back. That is a real cost and the exemption was honest.

It is also avoidable. `NSPasteboard(name:)` makes a board of one's own, so both conformers now hold a
pasteboard **name** rather than assuming the general one — a `Sendable` value, which the board itself
is not — and a test names its own, writes, reads back and releases it. The developer's clipboard is
never touched by `make test`, and the question *did pressing Copy put on the pasteboard the string the
row actually shows* has an answer for the first time. `clearContents()` before each write is not
ceremony: `NSPasteboard` accumulates type declarations and refuses a `setString` onto a board still
holding an older one, so without it a second copy silently leaves the first review there.

Both types lost the `UiKit` prefix with the behaviour that justified it. `DiagnosticCopyFailure`
survives for a host with neither framework, which is the one case the original sentence still
describes.

### The settings opener gained an argument, and then had to leave the view layer to keep it

This is the one place the Mac could not be given parity by filling in a branch. iOS hands an app
**one page** carrying every switch it has asked for, so all three screens wanted the same URL and the
act was written once with nothing to choose. macOS has no such page: Local Network and Camera are two
panes of Privacy & Security. A Mac branch with no argument would have opened one of them for all
three screens — and a reader sent to a Local Network switch because their *camera* is off has been
answered by a button that appeared to work, which is the same defect wearing a destination.

So `openSettings` takes a `SystemSettingsPane`. On iOS every case answers the app's own page, stated
as an assertion rather than as a comment, because a platform that split them would need that test to
fail rather than keep passing quietly.

**And the argument is what made the old placement untenable.** It had been a free function in
`Client/Connection/Presentation` with a comment excusing itself: *"it hands a URL the system owns to
the system and is told nothing back, so there is nothing for a fake to stand in for."* That was true
of the act and false of the decision beside it — and while the decision was "there is one URL", the
distinction cost nothing. The pane argument is a real choice with a real wrong answer whose failure is
silent, and the architecture rule it was sitting under says so in as many words: no `NSWorkspace` in a
view or a screen, and *"it is one line with nothing to decide" is the excuse to watch for — it stops
being true the moment a control that decides joins the ones that did not.*

**The coverage gate is what forced the issue rather than the rule.** The Snapshot row is measured over
the view layers alone, so twenty lines of URL mapping added to a `Presentation` module are twenty lines
no baseline can execute, and the row fell by a tenth of a point on a branch that lowered the project's
uncovered total by six lines. The seam fixes both at once: `SystemSettingsOpening` and its pane are
`Domain`, the URLs and the hand-over are `Data`, the model gains `openSettings(_:)` beside the
`copyLogs` it already had, and the view layer ends the slice *smaller* than it started.

`url(of:)` stays separated from the call that performs it, which is the Mac app's own arrangement
copied for its own reason: `SystemSettingsPaneUrl.swift` sits beside `AppKitSystemGestures` precisely
so the part that is a pure function keeps being measured while the unrunnable part is excused.

### The viewfinder is two wrappers over one layer

`AVCaptureVideoPreviewLayer` is the same class on both platforms; what differs is only which
representable protocol wraps it. So the configuration is written once and the two wrappers are four
lines each. The AppKit side sets `wantsLayer` by hand, which the UIKit side never needed: an `NSView`
has no layer until it is asked for one, so a preview attached without it would be attached to nothing
and the viewfinder would draw the same empty rectangle this change exists to stop drawing.

### What the Mac destination is *not* yet

**Its chrome is the iPad's.** The back-chevron in `WorktreeSplitScreen` is a nav-stack pattern a
native Mac app would not have, the sidebar is not a Mac sidebar, and no section of `design.md` covers
a Client screen as a Mac window. Davide's call is that this one is settled **in prose here rather than
through a Claude Design round trip** — the content of every screen is already drawn and it is only the
window around it that is new. That section is not written yet and no chrome has been changed, so this
slice ships a Mac app that works and looks like an iPad.

**It is not published, and nothing here publishes it.** Xcode Cloud archives the Client for iOS only.
A macOS workflow for it — and the Developer ID and notarisation workflow the menu bar app has been
missing since 0.0.x — are a separate slice with App Store Connect setup in it. That is why a Mac
destination can merge before its chrome exists without shipping half a screen to anybody.

**The multicast entitlement does not cross.** It is iOS-only and a Mac profile cannot carry it, so the
Mac destination is pointed at an empty entitlements file by SDK. It needs nothing in its place:
broadcast is ungated on macOS, and the Client is unsandboxed like its menu bar sibling.

### The two Mac apps needed two names, and the build system asked before anyone did

Both targets set `PRODUCT_NAME: Granita`. That cost nothing while the platforms were disjoint —
different SDKs, different products directories, no collision anyone could hit. Building both for
macOS puts two `create directory` commands on one bundle path in a single products directory, and the
build graph is refused outright: *Multiple commands produce `Granita.app`*. The bundle identifiers
already differed; the file name did not.

**This is a product fact rather than a build-system quirk**, which is why it was not worked around: a
reader cannot have two identically named apps in /Applications either, and the day the Mac Client is
distributed is the day that stops being hypothetical. Davide named both halves on 14 September 2026 —
**the menu bar app is *Granita Server*, the Mac Client is *Granita Client*.**

**The phone and the iPad keep `Granita`**, which is why the Client's is an SDK-conditional override
rather than a rename. That app is on TestFlight, its name is on a home screen, and nothing about the
collision reaches it. `CFBundleDisplayName` follows `$(PRODUCT_NAME)` rather than repeating a literal,
so the two resolve per platform from one place — a second literal is how the phone's name ends up
under the Mac app's icon.

**Three references had the old product name spelled out, and the third is the one worth naming.** Two
were found by reading: the Mac snapshot bundle's `TEST_HOST`, which cannot use `$(PRODUCT_NAME)`
because in a test target that means the *test bundle's* name, and `make run-mac`'s `open`. The third
was found by a red gate — `measure-coverage.sh` locates the Mach-O objects to read counters from by
writing the bundle path out, so the macOS pass built and ran and then reported *found no built product
to read coverage from*. **That failure mode is worth remembering: the rename does not break the build,
it breaks the measurement**, and the message names a directory rather than a product name. If it ever
appears again, check `PRODUCT_NAME` before anything else.

### The local gate agreed with CI only once the graph was cold

`make coverage` passed on this branch before the collision was introduced into it and **kept passing
after**, while CI failed on the same commit. The difference was warm derived data: the macOS pass
reused a build graph from before the Client had a Mac destination, so the two-targets-one-bundle
conflict was never computed. CI starts empty and computed it immediately.

The rule that falls out is narrow and worth keeping: **a change that adds a destination or a target
cannot be verified by an incremental local build.** `make build` and a warm `make coverage` are
evidence about the code, not about the graph. Deleting `build/derived` before the run is what made the
local answer match the runner's — both the failure and, after the rename, the pass.

