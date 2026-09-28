# The pairing invitation is a `Domain` type, because the tab that draws it cannot see the layer that makes it

`PairingInvitations` lives in `ServerApiPresentation`, behind Hummingbird, and `ServerMacPresentation`
may not depend on it — a `Presentation` target depending on another one is not a rule with an
exception for this. So the Devices tab could not simply call the thing that assembles a code.

What moved is the **value and the question**, not the assembly: `PairingInvitation` and a
`PairingInviting` protocol are in `ServerApiDomain` now, and the existing type conforms. That module
gained one dependency, `CorePairingDomain`, which is what a link is defined in. The composition root
wires the conformer in, exactly as it does for every other edge.

**The error changed shape on the way, and that is the half worth recording.** `invite` threw
`ServerIdentityError` — a Keychain vocabulary, in a signature the Devices tab would have had to
translate. It now throws `PairingInvitationError.noIdentity(reason:)`, carrying the sentence rather
than the status code, and the four sentences themselves moved to `ServerIdentityError.explanation` in
`ServerIdentityDomain` because **two surfaces say them about one fault**: an identity this Mac cannot
read stops it serving *and* stops it offering a code, and a reader who meets both should not be given
two vocabularies for the same locked keychain. `TransportResolvingServerHost` lost its private copy.

`PairingInvitation.lifetime` moved with the type for the same class of reason `ConnectionAttempt.logCapacity`
is in a `Domain` module: the countdown fills a bar against it and cannot see the actor that enforces
it, and a second copy of `120` is a bar that empties at a different rate than the code expires.
`Pairing.codeLifetime` is now that constant rather than a second literal.

