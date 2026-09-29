# `onChange` dies at `onDisappear`, and 0.1.0 shipped its pairing success on one that had

**Pairing hung forever on the in-flight frame, on both credentials, on a real iPhone.** The Mac's
document gained two device records ninety seconds apart and its log then refused a third attempt as
`pairingExpired` — so `POST /v1/pair` answered 200 twice, the phone kept the token, and the reader
sat under *Pairing with MacBook Pro / Checking the Mac, then spending the code.* with nothing to
press. 786 tests, 208 baselines and an adversarial audit were all green.

The watch for the one ending with no screen of its own lived on `PairingEntryScreen`, on the
reasoning written into its own doc comment: that screen sits under all three of the others, so it is
the one place that sees every path. **Being underneath is exactly what stopped it working.**
`onChange` is scoped to a view's *appearance*, not its lifetime, and a `NavigationStack` calls
`onDisappear` on a screen the moment something is pushed over it. By the time a pairing can succeed
there is always something over the Mac's screen — the viewfinder, or the six-word screen and the
outcome screen above it.

Measured rather than reasoned, in the simulator, with the entry screen logging its own body,
appearance and change: `onAppear` at push, `onDisappear` when the six-word screen arrived, then the
body evaluated three more times — including once with `pairing = finished(.paired(…))` — and
`onChange` never fired once. Three seconds later the stack was still three deep. **The body goes on
being evaluated, so in a debugger the observation looks alive**, which is why this survived review.

Success now hands over from the two screens that can be frontmost when a credential is spent — the
viewfinder and the outcome screen — through one modifier, `PairedMacHandover`, and nothing beneath
them watches for anything. It carries `initial: true` because the scanned path replaces the
viewfinder with the outcome screen the instant a spend finishes, so what the next screen arrives
holding is a state that has already stopped changing.

**What is asserted, and what is not.** `PairingState.pairedMac` is the handover as a value, and it is
covered against every state including the two other endings that carry a `PairedMac` — handing one of
those to the worktree list would open it against a token this phone never stored. **The
appearance-scoping itself is reachable by no test kind this project runs**: a unit test has no view
hierarchy, and a snapshot photographs one view value that was never pushed over. It took a simulator,
a seeded navigation path and a log. That is the second defect in this repository whose only witness
was running the app and pressing the thing.

