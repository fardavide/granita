# A screen was doing I/O, and the coverage gate had been reporting that for three runs

`GranitaSettingsScreen` held four AppKit statics — `NSOpenPanel`, `NSPasteboard`, `NSWorkspace`
twice — and the closures that called them. The comment excusing them said they were "one-line system
gestures with nothing to decide and nothing a test would assert; a seam here would be an abstraction
invented for a future nobody asked for". That was true when it was written and stopped being true
the moment Projects added a folder picker: **a picker decides.** It comes back with a folder or with
a reader who changed their mind, and every one of the three call sites branches on which.

The gate had been saying so and was misread. The Snapshot row fell and the reflex — twice recorded
in this file as wrong — was that the scope was mis-drawn. Measured per file through `coverage.py`'s
own reader, `GranitaSettingsScreen` was at **45 uncovered regions of 56**: not because it is a view,
but because a view body is where no test can supply an answer to a question the code asks.

**A scope change was proposed here and Davide refused it**, on 23 August 2026, with the argument
that settles it: *Ui must be declarative; if a state cannot be driven by a model, and it isn't
testable because of that, we have a structural issue.* The proposal would have excluded models from
the views scope and taken the number back over its baseline without touching the defect. It was the
third time this project has reached for a rescoping and the first time the reach was wrong.

So the I/O left the screen, which is what `architecture.md` has said all along — *anything that
touches the outside world sits behind a protocol its `Domain` owns, with one implementation in a
`Data` module and a hand-written fake in tests*. Two protocols, because they differ in the way that
matters: `FolderPicking` answers and `SystemGestures` does not. `AppKitFolderPicker` and
`AppKitSystemGestures` hold the AppKit; the model gained `addProjectFromPicker`,
`scanFolderFromPicker`, `locateProjectFromPicker`, `copyAddress`, `revealDataFolder` and
`openSystemSettings`, all of them ordinary methods a test drives; and the screen became composition
and nothing else.

**Three things came free, and each is the sort that was previously unaskable.** Whether the string
Copy puts on the pasteboard is the one the row shows — it is, and it is asserted now rather than
computed twice. Whether copying while the server is down copies the em dash the row draws — it does
not. And whether the two `x-apple.systempreferences:` literals still parse, which nothing in the
product would have noticed: a mistyped extension identifier opens System Settings on its front page,
which looks exactly like the app working.

**What is ticked in the scan sheet moved to the model in the same pass**, and the distinction is
worth keeping: a highlighted row drives nothing and stays the screen's own `@State`, while a ticked
checkbox decides what a confirm button will add and belongs beside the scan it came from.

Rejected: keeping `copy`, `reveal` and `openSystemSettings` inline on the grounds that they really
are one-liners with nothing to decide. They are — but they are I/O in a view either way, and leaving
three behind while moving the fourth would have been a rule applied by size rather than by kind.

