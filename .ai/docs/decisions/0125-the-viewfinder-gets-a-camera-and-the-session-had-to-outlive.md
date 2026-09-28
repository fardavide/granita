# The viewfinder gets a camera, and the session had to outlive the run to give it one

`CaptureSessionCodeScanner` said the live preview was not its business and that "the composition
root is the one place allowed to see both, which is where that join goes when the screen lands". The
screen has landed. What the join needed was not a new seam but a smaller change to the old one: the
session is now made **once, at construction, and never replaced**.

A preview layer follows a session *object*. One built per run, as this file did, cannot be attached
to anything before the camera opens — and the screen has to draw a viewfinder while the permission
alert is still up, which is the state §5 spends a paragraph on. An empty session opens no camera and
needs no grant, so it can exist from the moment the scanner does, and a second run reuses it: the
input stays on it, because taking the camera off to put an identical one back would blank the
preview in front of the reader, and only the metadata output is replaced, because the delegate it
reports to belongs to one run.

**The view that draws it is in `Ui`, not in the composition root**, even though the root is what
hands the session over. `AVCaptureVideoPreviewLayer` is a system framework and a `Ui` target may see
those; what a `Main` target may not hold is a `UIViewRepresentable` and a `UIView` subclass, because
a `Main` module is exempt from both coverage rows and logic left in one is untested code that no
longer looks untested.

The cost is stated rather than waved through: **not one line of any of this can be run on a build
machine**, so the only check that means anything is a device, and the session's own file has said
that about itself since it was written. What the design calls a frozen frame is a stopped session,
which is what §5's own sentence describes ("the session stops, the preview dims") and is not the
same as a held still.

### Two smaller calls in the same commit

**The entry screen resolves its own address line.** §5's frame draws `MacBook-Pro.local:59144` under
the two credentials and its prose never mentions it, so the drawing is the only authority and the
line is built. The lookup **returns rather than records** — a value kept on the model would sit
under the *next* Mac's name for as long as its own lookup took, which is a lie rather than a stale
caption — and it is silent on failure, which is right for a caption under two buttons: a Mac that
will not resolve says so properly, with a screen and a remedy, the moment a credential is spent on
it.

**TestFlight's scheme is declared in the property list**, because `canOpenURL` answers `false` for
any scheme that is not, whatever is installed. Without that line the decision recorded above it —
that the button appears only when the system says it can open it — would have been a rule that
always answers no, which is the same defect as the button that cannot work, wearing the rule that
was written to prevent it.

**`PairingNotReadyView` is deleted**, with its suite and its four baselines. It existed to say that
pairing had no screen, and it said so honestly for one release rather than leaving a row that did
nothing. There is a screen now.

