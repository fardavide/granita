# The pairing spine is one path, and only one of its three pushes is an ordinary push

Design §5 asks for four screens pushed in the stack discovery already has: *Macs → this Mac → Scan
or Words → the outcome*. Pushed is what shipped. What §5 does not draw is what happens when the
reader taps **back** from the fourth screen, and answering that is what shaped the other two.

**The outcome replaces the viewfinder and pushes over the field**, which looks like an inconsistency
and is two of §5's own sentences applied to the same event. Behind the words screen there is a
phrase worth returning to: "after a refusal the words screen keeps what was typed and says the code
is stale", which is the consequence that replaces the countdown this phone deliberately does not
draw. Behind the viewfinder there is a frozen frame, a stopped camera and a code that has already
been spent — §5's own reason for replacing the stack on success is "back must return to the Mac
list, never to a scanner holding a spent code", and a refusal leaves exactly the same screen behind.
So the scanner swaps itself out and back from the outcome lands on the Mac, one tap from either
credential.

**The two credentials are siblings by swapping the top of the stack, not by pushing.** *Enter the
Six Words* on the viewfinder removes the viewfinder and puts the field in its place, which is what
"the same depth" means when the button that moves between them is on the screen rather than in the
navigation bar. §5's prose describes the reader's route as "a back tap and a second tap"; the button
is that route in one gesture, and it lands them in the same place.

**Nothing about this is expressible without a path the screens can assign to**, so the stack gained
one and the composition root holds it. That is also the whole of why success can be what §5 says it
is — a replacement rather than a fifth screen — and it is the reason `NavigationPath` is
type-erased here rather than an array of one route enum: each hop keeps its own value type, so each
destination can be declared beside the link that reaches it.

### One route type for the three pairing screens, because "beside the link" needs help two levels in

The rule this project learned the hard way is that a link and its destination live in one file. It
holds for the Mac's row and for the two credentials, whose links are on the screen that declares
them. It cannot hold literally for the outcome, whose links are on the two screens *below* the one
that declares it.

So `PairingStep` is one enum with one destination and one **exhaustive** switch over it. What that
buys is stronger than proximity: a step added without a screen does not compile. The alternative
considered was a `navigationDestination` in each of the two credential screens — legal, since they
are never in the stack together — and it is two copies of one composition, drifting from the day the
outcome screen gains a parameter.

`PairingStep.theOutcome` carries **no payload**, which is what removed the last argument for those
two copies. The screen draws the model's state, and what *Try Again* would spend again is the
credential the model kept — so the model grew `spentCredential`, and a route that carried either of
them would have been a second copy able to disagree with the first.

### Going back is refused in two places, because a code is spent in two

The viewfinder hides its back button while a credential is in flight, which is where §5 draws it.
The outcome screen hides its own for `spending` and `savingToken`, which §5 does not draw because
the frame it drew had no button and therefore no wait: the words path spends its code on *this*
screen, and the Keychain retry that Davide added spends the token it bought here too. Hidden rather
than dimmed in both, for the reason recorded when the viewfinder shipped — SwiftUI has no disabled
back button, and drawing our own is hand-building the one piece of chrome the system owns.

