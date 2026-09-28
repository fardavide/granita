# Joining a Mac is a use case, and the coverage gate is what said so

The first draft put the sequence — read the contract, spend the code, write the token down — on
`ClientConnectionModel`, which is a `Presentation` type. It looked reasonable and it was a layer
violation: a view model orchestrating three protocols is a use case wearing a screen's name, and the
rule that use cases orchestrate exists precisely so that the thing worth testing is not sitting in
the layer that is hardest to reach.

**The Snapshot coverage row is what caught it**, and it caught it as a number rather than as an
opinion. That row is scoped to the layers that draw, which includes `Presentation` because a screen
is composed there — so ninety lines of pairing logic that no rendered baseline could ever execute
joined its denominator and dropped it twelve points. The reflex is to rescope the row; the honest
reading is that the row was right and the code was in the wrong place.

So `MacPairing` is a `Domain` type over the two protocols it needs, returning a `PairingOutcome`
rather than throwing — three of the four endings are not errors in any useful sense, and a caller
that had to catch them would be deciding which of its `catch` blocks was really a success. The model
keeps what a screen reads: not started, joining, finished. `MacJoining` is the protocol between them,
and it earns its place the ordinary way — the model's tests drive one fake instead of the two
collaborators underneath it, which is the difference between a test about the screen and a second
copy of the test below.

Rejected: scoping the Snapshot row to `Ui` alone. It would have passed the gate today by redefining
a number rather than by fixing what the number was reporting, which is the failure signature the
`swift-testing` skill names — and it would have stopped counting screen composition, which is
drawing code a baseline genuinely does execute.

### The row is right twice, and the second time it says: do not ship a screen's API before the screen

Moving the sequence out took Snapshot lines 83.2% to 88.0% and it was still short, which is the same
sentence one step further in. What was left in the views scope was five members of
`ClientConnectionModel` that **nothing calls** — `PairingState`, `pairing`, `pairedServers`,
`loadPairingHistory()`, `join(_:as:)` — plus the composition root's `handshake:` closure, which only
runs during a pairing attempt. There is no scanner and no pairing sheet, by design: neither has
frames, and the `design-handoff` rule forbids the pull request that would draw them.

So the pairing surface lands with the screen that reads it. `MacPairing` and the whole `Data` layer
stay, tested and judged by the Unit row; what leaves is a property no screen has agreed to and a
wiring line nothing reaches. That is the only option of the four considered that leaves the Snapshot
row **judged**, so the pull request is measured on the same terms as `main` and the ratchet survives
a milestone that added a thousand lines.

**And a belief that had to be corrected before any of this could be sized.** The snapshot bundle is
app-hosted — `TEST_HOST` is `Granita.app`, which is the only reason `drawHierarchyInKeyWindow`
works — so the host's `@main` really launches and the scene, the screen and the model's `init` and
`start()` all execute where the profile is written. They are *not* dead code in that pass, and the
95.7% baseline is arithmetically impossible if they were. An earlier plan to exempt composition roots
from the views scope was abandoned on that evidence: it would have removed a file that is 90%
covered from a denominator sitting at 90%, which moves the row a point, not eight.

The numbers came from running `measure-coverage.sh` locally and reading `snapshot.json` per file.
Three estimates of this had been wrong before that; a per-file export settles in one simulator pass
what algebra kept getting wrong.

### `isPermissionRefused` was a second place deciding one thing

Removed with the above, and it earns its own line because it predates the pull request. The model
exposed `discovery == .localNetworkDenied` as a property; the view already reaches that conclusion
from the state it is handed, and nothing in the app ever read the property — only its own two tests
did. The `swift-style` rule against a helper that merely shortens an inline expression covers it
exactly, and two places deciding one thing is the more expensive half.

Stated plainly because it is also the thing that bought the Snapshot row its margin: after the trim
above the row cleared by 0.13 of a point on lines and sat level on regions, which is inside the
noise of a different runner. Removing dead API for a good reason and needing headroom happened to be
the same edit, and the honest thing is to say so rather than to let it read as tidy-up.

### The one line in the report that did not compare like with like

Found while reading the script for the above. The table skips a row whose scope changed and so does
the gate, but the "N uncovered lines — M more than the baseline" sentence read `categories.all.lines`
straight out of both summaries with no such guard. On this very pull request that made it a
subtraction across two different file sets, reported as a trend. It now asks the same question the
gate asks, and says nothing when the answer is no.

