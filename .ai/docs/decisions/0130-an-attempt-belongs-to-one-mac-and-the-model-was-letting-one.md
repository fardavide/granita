# An attempt belongs to one Mac, and the model was letting one outlive its screen

One `ClientConnectionModel` serves the whole app, which is the right shape — discovery and pairing
are one question — and it had no notion of an attempt ending. Nothing cleared what a spend left
behind, so three of design §5's four screens could be drawn about a machine the reader had walked
away from.

The worst of it was *Try Again*. The outcome screen chose between the two credentials by asking the
model what it last spent; the words path, when the address would not resolve, set a state and left
that value untouched. So: scan one Mac, be refused, back out, open a second, type its six words,
watch the lookup fail, tap Try Again — and the first Mac's link is spent, at the first Mac, under
the second Mac's name in the title bar. **The screen a reader is looking at would have been about a
different computer than the one they paired with.**

Three changes, and each is a different half of the same rule.

1. **Opening a Mac's own screen starts an attempt.** `beginPairing(with:)` clears the outcome, the
   phrase and the credential, and the entry screen calls it from the task it already had. It sits
   under all three of the others, so it is the one place that sees every arrival. Unconditional
   rather than only when the Mac changes: coming back to the Mac that just refused you is starting
   an attempt too, and that is the case where the viewfinder re-opened on a dimmed frame reading
   *Pairing with…* with its back button hidden for a request nobody had made.
2. **Every path that tries to spend says what it spent, including the ones that spend nothing.** Six
   words that never found an address spent nothing, so that path now writes `nil` rather than
   leaving an older attempt's credential for a retry to find.
3. **The retry is handed the Mac.** `spendAgain(on:as:)` lives on the model and takes the Mac the
   screen is titled after, and a credential recorded against any other one is not offered back. That
   is the guarantee that does not depend on a view lifecycle, and it is asserted without one: a test
   drives the whole cross-Mac sequence and a second drives it with the reset deliberately skipped.

**`spentCredential` went private with the third change, and that is the point rather than a
side-effect.** It was public because a screen switched on it; now the model answers the question
instead, so there is one place that decides what a retry means rather than a value and a screen that
can disagree about it. `join(_:as:)` stopped being public for the same reason — nothing outside this
module ever called it.

Rejected: leaving the choice in `PairingOutcomeScreen` and merely clearing more state. It would have
fixed today's sequence and left the next screen free to make the same reading, and the thing that
went wrong here is precisely that a value with no owner was consulted by something that could not
know what it meant.

